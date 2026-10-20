import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "https://owvvimydkjsjlrmnzvdi.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF";
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
});

const $ = (id) => document.getElementById(id);
const authPanel = $("auth-panel");
const accountPanel = $("account-panel");
const adminPanel = $("admin-panel");
const notice = $("notice");
const signinForm = $("signin-form");
const signupForm = $("signup-form");
const roleOptions = [
  ["chairman", "Chairman"], ["vice_chairman", "Vice Chairman"],
  ["secretary", "Secretary"], ["team_manager", "Team Manager"],
  ["treasurer", "Treasurer"], ["coach", "Coach"],
  ["sponsor_lead", "Sponsor Lead"], ["media_team", "Media Team"]
];

function message(text, kind = "info") {
  notice.textContent = text;
  notice.dataset.kind = kind;
  notice.classList.remove("access-hidden");
}
function show(el, yes) { el.classList.toggle("access-hidden", !yes); }
function el(tag, text, cls) {
  const node = document.createElement(tag);
  if (text !== undefined && text !== null) node.textContent = String(text);
  if (cls) node.className = cls;
  return node;
}
function button(label, action, cls = "button button-dark") {
  const b = el("button", label, cls);
  b.type = "button";
  b.addEventListener("click", action);
  return b;
}
function table(headers, rows) {
  const t = el("table", null, "access-table");
  const thead = el("thead"); const tr = el("tr");
  headers.forEach(h => tr.append(el("th", h)));
  thead.append(tr); t.append(thead);
  const tbody = el("tbody");
  rows.forEach(cells => {
    const row = el("tr");
    cells.forEach(cell => {
      const td = el("td");
      if (cell instanceof Node) td.append(cell); else td.textContent = cell == null ? "—" : String(cell);
      row.append(td);
    });
    tbody.append(row);
  });
  t.append(tbody);
  return t;
}
async function currentSession() {
  const { data, error } = await supabase.auth.getSession();
  if (error) throw error;
  return data.session;
}
function genericError(error, fallback) {
  const text = (error && typeof error.message === "string") ? error.message : "";
  if (/invalid login credentials/i.test(text)) return "Sign-in failed. Check your email and password.";
  if (/email not confirmed/i.test(text)) return "Please verify your email using the confirmation message before signing in.";
  if (/password/i.test(text) && /12|weak|short/i.test(text)) return "Use a stronger password that meets the displayed requirements.";
  if (/active platform admin required/i.test(text)) return "This action is restricted to an active Platform Admin.";
  if (/email verification is required/i.test(text)) return "The account must verify its email before approval.";
  if (/target must be email-verified and approved first/i.test(text)) return "Approve and verify the account before assigning a role.";
  return fallback;
}
async function rpc(name, args) {
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw error;
  return data;
}
function switchTab(tab) {
  const signup = tab === "signup";
  show(signinForm, !signup); show(signupForm, signup);
  $("tab-signin").setAttribute("aria-pressed", String(!signup));
  $("tab-signup").setAttribute("aria-pressed", String(signup));
}
$("tab-signin").addEventListener("click", () => switchTab("signin"));
$("tab-signup").addEventListener("click", () => switchTab("signup"));

signupForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const fd = new FormData(signupForm);
  const name = String(fd.get("display_name") || "").trim();
  const email = String(fd.get("email") || "").trim().toLowerCase();
  const password = String(fd.get("password") || "");
  const confirm = String(fd.get("confirm_password") || "");
  if (password !== confirm) return message("The passwords do not match.", "error");
  if (password.length < 12) return message("Use a password of at least 12 characters.", "error");
  const submit = signupForm.querySelector('button[type="submit"]');
  submit.disabled = true;
  try {
    const { data, error } = await supabase.auth.signUp({
      email, password,
      options: {
        data: { display_name: name },
        emailRedirectTo: window.location.origin + "/app/index.html"
      }
    });
    if (error) throw error;
    if (data.session) await supabase.auth.signOut();
    message("Registration submitted. Check your email and open the verification link. After verification, sign in to check the approval status. Registration does not grant a role.", "success");
    signupForm.reset();
    switchTab("signin");
  } catch (error) {
    message(genericError(error, "Registration could not be completed. Check the details and try again."), "error");
  } finally { submit.disabled = false; }
});

signinForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const fd = new FormData(signinForm);
  const submit = signinForm.querySelector('button[type="submit"]');
  submit.disabled = true;
  try {
    const { error } = await supabase.auth.signInWithPassword({
      email: String(fd.get("email") || "").trim().toLowerCase(),
      password: String(fd.get("password") || "")
    });
    if (error) throw error;
    signinForm.reset();
    await loadAccess();
  } catch (error) {
    message(genericError(error, "Sign-in could not be completed. Verify your email and check your credentials."), "error");
  } finally { submit.disabled = false; }
});

$("signout").addEventListener("click", async () => {
  const { error } = await supabase.auth.signOut();
  if (error) message("Could not sign out. Please try again.", "error");
  else { resetPanels(); message("You have signed out.", "success"); }
});
$("refresh-status").addEventListener("click", loadAccess);
$("refresh-queue").addEventListener("click", loadAdminQueue);
$("show-audit").addEventListener("click", loadAudit);

function resetPanels() {
  show(authPanel, true); show(accountPanel, false); show(adminPanel, false);
}
async function loadAccess() {
  try {
    const session = await currentSession();
    if (!session) { resetPanels(); message("Sign in or create an account to continue."); return; }
    show(authPanel, false); show(accountPanel, true);
    const status = await rpc("get_my_access_status");
    const lines = [];
    if (status.platform_admin) lines.push("Platform Admin access is active. Use the protected approval dashboard below.");
    else if (!status.email_verified) lines.push("Email verification is still required. Check your inbox and spam folder.");
    else if (status.status === "pending") lines.push("Your email is verified. Your access request is pending Platform Admin approval.");
    else if (status.status === "rejected") lines.push("Your access request was rejected. Contact the club through its published contact channels if you believe this is an error.");
    else if (status.status === "suspended") lines.push("Your club access is suspended. Private club data and operations are unavailable.");
    else if (status.status === "revoked") lines.push("Your club access has been revoked. Private club data and operations are unavailable.");
    else if (status.status === "approved" && !status.role) lines.push("Your access is approved, but a club role has not yet been assigned. Club operations remain unavailable.");
    else if (status.access_granted) lines.push("Your account is approved and has an active role: " + status.role.replaceAll("_", " ") + ".");
    else lines.push("Your account does not currently have permission to use club management.");
    $("account-summary").textContent = lines.join(" ");
    message("Access status refreshed from the production database.", "success");
    show(adminPanel, Boolean(status.platform_admin));
    if (status.platform_admin) await loadAdminQueue();
  } catch (error) {
    show(authPanel, true); show(accountPanel, false); show(adminPanel, false);
    message(genericError(error, "The production access workflow is not available yet. Please try again later. No access has been granted by this page."), "error");
  }
}

async function loadAdminQueue() {
  const container = $("request-list");
  container.replaceChildren(el("p", "Loading access requests…"));
  try {
    const data = await rpc("admin_list_access_requests");
    const rows = Array.isArray(data) ? data : [];
    if (!rows.length) { container.replaceChildren(el("p", "No access requests found.")); return; }
    const rendered = rows.map(item => {
      const actions = el("div");
      actions.className = "access-form";
      const status = el("strong", item.status);
      const controls = el("div", null, "access-actions");
      if (item.status !== "approved") controls.append(button("Approve", () => changeStatus(item.user_id, "approved")));
      if (item.status !== "rejected") controls.append(button("Reject", () => changeStatus(item.user_id, "rejected")));
      if (item.status !== "suspended") controls.append(button("Suspend", () => changeStatus(item.user_id, "suspended")));
      if (item.status !== "approved") controls.append(button("Reinstate", () => changeStatus(item.user_id, "approved")));
      if (item.status !== "revoked") controls.append(button("Revoke", () => changeStatus(item.user_id, "revoked")));
      const roleSelect = el("select");
      roleSelect.setAttribute("aria-label", "New club role");
      roleSelect.append(new Option("Assign/change role…", ""));
      roleOptions.forEach(([value, label]) => roleSelect.append(new Option(label, value)));
      const reason = el("input");
      reason.type = "text"; reason.maxLength = 1000; reason.placeholder = "Reason required (min 3 characters)";
      reason.setAttribute("aria-label", "Role change reason");
      const assign = button("Assign role", async () => {
        if (!roleSelect.value || reason.value.trim().length < 3) return message("Choose a role and enter a reason of at least 3 characters.", "error");
        try {
          await rpc("admin_assign_club_role", {
            _target_user_id: item.user_id, _new_role: roleSelect.value, _reason: reason.value.trim()
          });
          message("Role assignment recorded in the audit log.", "success");
          await loadAdminQueue();
        } catch (error) { message(genericError(error, "Role assignment failed; no success was reported."), "error"); }
      });
      const roleControls = el("div", null, "access-form");
      roleControls.append(roleSelect, reason, assign);
      actions.append(status, controls);
      if (item.status === "approved" && item.email_verified) actions.append(roleControls);
      const cell = el("div"); cell.append(actions);
      return [item.display_name || "Member", item.email || "", item.email_verified ? "Verified" : "Not verified", item.requested_at ? new Date(item.requested_at).toLocaleString() : "—", item.role || "No role", cell];
    });
    container.replaceChildren(table(["Name", "Email", "Email", "Requested", "Active role", "Admin actions"], rendered));
  } catch (error) {
    container.replaceChildren(el("p", genericError(error, "Could not load the request queue. Confirm Platform Admin access and migration status.")));
  }
}

async function changeStatus(userId, newStatus) {
  const reason = window.prompt("Required reason for this access decision (at least 3 characters):");
  if (reason === null) return;
  if (reason.trim().length < 3) return message("A reason of at least 3 characters is required.", "error");
  try {
    await rpc("admin_set_account_status", {
      _target_user_id: userId, _new_status: newStatus, _reason: reason.trim()
    });
    message("Access status changed and written to the audit log.", "success");
    await loadAdminQueue();
  } catch (error) { message(genericError(error, "The access decision failed; no success was reported."), "error"); }
}

async function loadAudit() {
  const section = $("audit-section"); show(section, true);
  const container = $("audit-list"); container.replaceChildren(el("p", "Loading audit history…"));
  try {
    const data = await rpc("admin_get_audit_events", { _limit: 100 });
    const rows = (Array.isArray(data) ? data : []).map(item => [
      item.timestamp ? new Date(item.timestamp).toLocaleString() : "—",
      item.actor_email || item.actor_user_id || "System/bootstrap",
      item.target_email || item.target_user_id || "—",
      item.action,
      JSON.stringify({ old: item.old_value, new: item.new_value }),
      item.reason || "—"
    ]);
    container.replaceChildren(rows.length ? table(["Timestamp", "Actor", "Target", "Action", "Change", "Reason"], rows) : el("p", "No audit events recorded."));
  } catch (error) { container.replaceChildren(el("p", genericError(error, "Could not load audit history."))); }
}

supabase.auth.onAuthStateChange((event, session) => {
  if (event === "SIGNED_OUT" || !session) resetPanels();
  else if (event === "SIGNED_IN" || event === "TOKEN_REFRESHED" || event === "USER_UPDATED") {
    queueMicrotask(() => loadAccess());
  }
});

(async () => {
  try {
    const session = await currentSession();
    if (session) await loadAccess();
    else { resetPanels(); message("Sign in or create an account to continue."); }
  } catch {
    message("Could not connect to the access service. Check your connection and try again.", "error");
  }
})();
