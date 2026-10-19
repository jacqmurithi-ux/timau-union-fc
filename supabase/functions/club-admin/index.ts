// REVIEW DRAFT ONLY — do not deploy until independent review and release gates pass.
// All writes are server-mediated. SUPABASE_SERVICE_ROLE_KEY must remain a server secret.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedRoles = new Set(["vice_chairman", "secretary", "team_manager", "treasurer", "coach", "sponsor_lead", "media_team"]);
const allowedActions = new Set(["invite", "activate_invitation", "cancel_invitation", "suspend_membership", "restore_membership", "revoke_membership", "assign_role", "revoke_role", "chairman_handover"]);
const originList = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
const jsonHeaders = { "Content-Type": "application/json", "Vary": "Origin" };

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  const cors: Record<string, string> = { ...jsonHeaders, "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, idempotency-key", "Access-Control-Allow-Methods": "POST, OPTIONS" };
  if (origin && originList.includes(origin)) cors["Access-Control-Allow-Origin"] = origin;
  if (origin && !originList.includes(origin)) return response(403, { error: "origin_not_allowed" }, cors);
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return response(405, { error: "method_not_allowed" }, cors);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!url || !serviceKey || !anonKey || !authHeader?.startsWith("Bearer ")) return response(401, { error: "unauthorized" }, cors);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await caller.auth.getUser();
  if (authError || !authData.user) return response(401, { error: "invalid_session" }, cors);
  const actor = authData.user;
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return response(400, { error: "invalid_json" }, cors); }
  const action = typeof body.action === "string" ? body.action : "";
  if (!allowedActions.has(action)) return response(400, { error: "unsupported_action" }, cors);

  // Activation is self-service only; the actor ID always comes from verified Auth.
  if (action === "activate_invitation") {
    const invitationId = uuid(body.invitation_id);
    if (!invitationId) return response(400, { error: "invalid_invitation_id" }, cors);
    const { data, error } = await admin.rpc("club_admin_activate_invitation", { _actor: actor.id, _invitation_id: invitationId });
    if (error) return response(mapStatus(error.code), { error: safeError(error.message) }, cors);
    return response(200, { status: data }, cors);
  }

  // Re-check live DB membership/role on every privileged request; never trust JWT metadata.
  const { data: membership, error: membershipError } = await admin.from("club_memberships")
    .select("id,status").eq("user_id", actor.id).maybeSingle();
  if (membershipError || membership?.status !== "active") return response(403, { error: "chairman_required" }, cors);
  const { data: chairman, error: chairmanError } = await admin.from("role_assignments")
    .select("id").eq("membership_id", membership.id).eq("role_key", "chairman").is("revoked_at", null).maybeSingle();
  if (chairmanError || !chairman) return response(403, { error: "chairman_required" }, cors);

  if (action === "invite") {
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const role = typeof body.role === "string" ? body.role : "";
    const requestKey = uuid(req.headers.get("Idempotency-Key") ?? body.request_key);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 320 || !allowedRoles.has(role) || !requestKey) {
      return response(400, { error: "invalid_invitation" }, cors);
    }
    if (email === (actor.email ?? "").trim().toLowerCase()) return response(409, { error: "self_assignment_not_allowed" }, cors);
    const { data: invitationId, error: beginError } = await admin.rpc("club_admin_begin_invitation", {
      _actor: actor.id, _email: email, _role_key: role, _request_key: requestKey,
    });
    if (beginError) return response(mapStatus(beginError.code), { error: safeError(beginError.message) }, cors);

    const { data: claimed, error: claimError } = await admin.rpc("club_admin_claim_invitation", { _invitation_id: invitationId });
    if (claimError) return response(503, { error: "invitation_queue_unavailable", invitation_id: invitationId }, cors);
    const row = Array.isArray(claimed) ? claimed[0] : claimed;
    if (!row) {
      const { data: current } = await admin.from("invitation_requests").select("state").eq("id", invitationId).maybeSingle();
      return response(current?.state === "sent" ? 200 : 409, { invitation_id: invitationId, state: current?.state ?? "not_claimable" }, cors);
    }

    const redirectTo = Deno.env.get("INVITE_REDIRECT_URL");
    if (!redirectTo) {
      await admin.rpc("club_admin_finish_invitation", { _invitation_id: invitationId, _success: false, _auth_user_id: null, _error_code: "invite_redirect_not_configured" });
      return response(503, { error: "invitation_delivery_not_configured" }, cors);
    }
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo });
    if (inviteError || !invited.user) {
      await admin.rpc("club_admin_finish_invitation", {
        _invitation_id: invitationId, _success: false, _auth_user_id: null,
        _error_code: inviteError ? "auth_invite_failed" : "auth_user_missing",
      });
      return response(502, { error: "invitation_delivery_failed", invitation_id: invitationId }, cors);
    }
    const { data: finishState, error: finishError } = await admin.rpc("club_admin_finish_invitation", {
      _invitation_id: invitationId, _success: true, _auth_user_id: invited.user.id, _error_code: null,
    });
    // Auth delivery and Postgres cannot share a distributed transaction. Do not auto-resend
    // if finalization fails: return a reconciliation marker and preserve the request ID.
    if (finishError) return response(503, { error: "invitation_reconciliation_required", invitation_id: invitationId }, cors);
    return response(200, { invitation_id: invitationId, state: finishState }, cors);
  }

  let rpcName: string;
  let args: Record<string, unknown>;
  if (action === "cancel_invitation") {
    const invitationId = uuid(body.invitation_id);
    if (!invitationId) return response(400, { error: "invalid_invitation_id" }, cors);
    rpcName = "club_admin_cancel_invitation";
    args = { _actor: actor.id, _invitation_id: invitationId };
  } else if (action === "suspend_membership" || action === "restore_membership" || action === "revoke_membership") {
    const target = uuid(body.user_id);
    if (!target) return response(400, { error: "invalid_user_id" }, cors);
    rpcName = "club_admin_manage_membership";
    args = { _actor: actor.id, _target_user_id: target, _action: action.replace("_membership", "") };
  } else if (action === "assign_role" || action === "revoke_role") {
    const target = uuid(body.user_id);
    if (!target) return response(400, { error: "invalid_user_id" }, cors);
    const role = typeof body.role === "string" ? body.role : "";
    if (!allowedRoles.has(role)) return response(400, { error: "invalid_role" }, cors);
    rpcName = "club_admin_change_role";
    args = { _actor: actor.id, _target_user_id: target, _role_key: role, _action: action === "assign_role" ? "assign" : "revoke", _note: cleanNote(body.note) };
  } else if (action === "chairman_handover") {
    const target = uuid(body.user_id);
    if (!target) return response(400, { error: "invalid_user_id" }, cors);
    rpcName = "club_admin_handover_chairman";
    args = { _actor: actor.id, _successor_user_id: target, _note: cleanNote(body.note) };
  } else {
    return response(400, { error: "unsupported_action" }, cors);
  }
  const { data, error } = await admin.rpc(rpcName, args);
  if (error) return response(mapStatus(error.code), { error: safeError(error.message) }, cors);
  return response(200, { status: data }, cors);
});

function uuid(value: unknown): string | null {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) return null;
  return value;
}
function cleanNote(value: unknown): string | null {
  return typeof value === "string" && value.trim().length <= 500 ? value.trim() || null : null;
}
function mapStatus(code?: string): number {
  if (code === "42501") return 403;
  if (code === "23505" || code === "40001") return 409;
  if (code === "22023" || code === "22P02") return 400;
  if (code === "P0002") return 404;
  return 500;
}
function safeError(message: string): string {
  const allowed = new Set([
    "chairman_required", "invalid_invitation", "self_assignment_not_allowed", "idempotency_key_conflict",
    "email_already_has_membership", "invitation_not_claimed", "invitation_not_activatable", "invitation_expired",
    "verified_invited_identity_required", "membership_not_activatable", "invitation_not_cancellable",
    "self_management_not_allowed", "membership_not_found", "invalid_membership_transition", "invalid_role_change",
    "active_membership_required", "active_role_not_found", "chairman_handover_required", "invalid_handover",
    "current_chairman_required", "active_successor_required", "successor_already_chairman",
  ]);
  return allowed.has(message) ? message : "request_failed";
}
function response(status: number, value: Record<string, unknown>, headers: Record<string, string> = jsonHeaders) {
  return new Response(JSON.stringify(value), { status, headers });
}
