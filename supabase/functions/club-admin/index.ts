// REVIEW DRAFT ONLY — do not deploy until the SQL RPCs and tests are approved.
// Edge Function entry point for Chairman-only identity/role governance.
// Store SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY as function secrets only.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedRoles = new Set(["chairman","vice_chairman","secretary","team_manager","treasurer","coach","sponsor_lead","media_team"]);
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json" };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!url || !serviceKey || !authHeader?.startsWith("Bearer ")) return json(401, { error: "unauthorized" });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const callerClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const { data: authData, error: authError } = await callerClient.auth.getUser();
  if (authError || !authData.user) return json(401, { error: "invalid_session" });
  const actorId = authData.user.id;

  const { data: actorMembership, error: actorError } = await admin
    .from("club_memberships").select("id,status").eq("user_id", actorId).maybeSingle();
  if (actorError || actorMembership?.status !== "active") return json(403, { error: "chairman_required" });
  const { data: actorRole, error: roleError } = await admin
    .from("role_assignments").select("id").eq("membership_id", actorMembership.id)
    .eq("role_key", "chairman").is("revoked_at", null).maybeSingle();
  if (roleError || !actorRole) return json(403, { error: "chairman_required" });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json(400, { error: "invalid_json" }); }
  const action = body.action;
  if (action === "invite") {
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const role = typeof body.role === "string" ? body.role : "";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 320 || !allowedRoles.has(role)) return json(400, { error: "invalid_invitation" });
    if (email === (authData.user.email ?? "").trim().toLowerCase()) return json(409, { error: "self_assignment_not_allowed" });

    // REQUIRED BEFORE RELEASE: implement a database RPC that atomically creates
    // an invited membership + role assignment + audit event, with a unique
    // pending-invitation key/idempotency key. Do not call Auth Admin first:
    // doing so without an atomic outbox leaves orphan invites on DB failure.
    // This placeholder intentionally fails closed rather than partially inviting.
    return json(501, { error: "invitation_transaction_not_implemented", release_blocker: true });
  }

  // No unsupported action may fall through to a privileged generic database write.
  return json(400, { error: "unsupported_action" });
});

function json(status: number, value: Record<string, unknown>) {
  return new Response(JSON.stringify(value), { status, headers: cors });
}
