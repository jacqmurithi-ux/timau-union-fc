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
const resetRequestForm = $("reset-request-form");
const updatePasswordForm = $("update-password-form");
let recoveryMode = false;
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
  show(resetRequestForm, false); show(updatePasswordForm, false);
  show($("tab-signin"), true); show($("tab-signup"), true);
  $("tab-signin").setAttribute("aria-pressed", String(!signup));
  $("tab-signup").setAttribute("aria-pressed", String(signup));
}
function recoveryRequestedInUrl() {
  const search = new URLSearchParams(window.location.search);
  const hash = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  return search.get("recovery") === "1" ||
    search.get("type") === "recovery" ||
    hash.get("type") === "recovery" ||
    hash.get("error_code") === "otp_expired" ||
    hash.get("error") === "access_denied";
}
function showRecoveryForm() {
  recoveryMode = true;
  show(authPanel, true); show(accountPanel, false); show(adminPanel, false);
  show(signinForm, false); show(signupForm, false); show(resetRequestForm, false);
  show(updatePasswordForm, true);
  show($("tab-signin"), false); show($("tab-signup"), false);
  message("Password recovery opened. If the link is expired or invalid, request a new reset email. Choose a new password below only after a valid recovery link has been accepted.", "success");
}
$("tab-signin").addEventListener("click", () => switchTab("signin"));
$("tab-signup").addEventListener("click", () => switchTab("signup"));
$("forgot-password").addEventListener("click", () => {
  resetRequestForm.elements.email.value = signinForm.elements.email.value.trim().toLowerCase();
  show(signinForm, false); show(signupForm, false); show(resetRequestForm, true); show(updatePasswordForm, false);
  message("Enter your email address to request a password reset.");
});
$("cancel-reset-request").addEventListener("click", () => {
  resetRequestForm.reset(); switchTab("signin");
  message("Return to sign in when you're ready.");
});

resetRequestForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const email = String(new FormData(resetRequestForm).get("email") || "").trim().toLowerCase();
  const submit = resetRequestForm.querySelector('button[type="submit"]');
  submit.disabled = true;
  try {
    const redirect = new URL("./index.html", window.location.href);
    redirect.search = "?recovery=1";
    redirect.hash = "";
    const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: redirect.toString() });
    if (error) throw error;
    message("If an account is associated with that email, a password reset link will be sent. Check your inbox and spam folder.", "success");
    resetRequestForm.reset();
  } catch (error) {
    console.error("Timau Union FC password-reset request failed:", error);
    const detail = error && typeof error.message === "string" ? error.message.trim() : "";
    const status = error && Number.isFinite(error.status) ? ` (HTTP ${error.status})` : "";
    const code = error && typeof error.code === "string" ? ` [${error.code}]` : "";
    const safeDetail = detail && detail.length <= 220 ? detail : "";
    message(safeDetail ? `Password reset failed${status}${code}: ${safeDetail}` : genericError(error, "Password reset failed. Check Supabase Auth email delivery settings and allowed redirect URLs, then try again."), "error");
  } finally { submit.disabled = false; }
});

updatePasswordForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const fd = new FormData(updatePasswordForm);
  const password = String(fd.get("password") || "");
  const confirm = String(fd.get("confirm_password") || "");
  if (password.length < 12) return message("Use a password of at least 12 characters.", "error");
  if (password !== confirm) return message("The new passwords do not match.", "error");
  const submit = updatePasswordForm.querySelector('button[type="submit"]');
  submit.disabled = true;
  try {
    if (!recoveryMode) throw new Error("A valid password recovery session is required.");
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw error;
    recoveryMode = false;
    updatePasswordForm.reset();
    await supabase.auth.signOut();
    switchTab("signin");
    message("Password updated. Sign in using your new password.", "success");
  } catch (error) {
    message(genericError(error, "Password update failed. Reopen the latest reset link from your email and try again."), "error");
  } finally { submit.disabled = false; }
});

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
    const emailRedirect = new URL(window.location.href);
    emailRedirect.search = "";
    emailRedirect.hash = "";
    const { data, error } = await supabase.auth.signUp({
      email, password,
      options: {
        data: { display_name: name },
        emailRedirectTo: emailRedirect.toString()
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
    message(genericError(error, "Sign-in failed. Check your email and password, confirm your email is verified, and try again. If it continues, request a password reset."), "error");
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
    show($("workspace-link"), Boolean(status.access_granted && status.role));
    message("Access status refreshed from the production database.", "success");
    show(adminPanel, Boolean(status.platform_admin));
    if (status.platform_admin) { await loadAdminQueue(); await loadInstallStats(); }
  } catch (error) {
    show(authPanel, true); show(accountPanel, false); show(adminPanel, false);
    message(genericError(error, "The production access workflow is not available yet. Please try again later. No access has been granted by this page."), "error");
  }
}

let installStatsData = null;
function installSummary(p) {
  return [
    "Timau Union FC — App install statistics",
    `Total installs: ${p.total_installs ?? 0}`,
    `Today: ${p.installs_today ?? 0}`,
    `Last 7 days: ${p.installs_7d ?? 0}`,
    `Last 30 days: ${p.installs_30d ?? 0}`,
    `Active installs (30 days): ${p.active_installs_30d ?? 0}`,
    `Prompts shown (30 days): ${p.prompts_shown_30d ?? 0}`,
    `Prompts accepted (30 days): ${p.prompts_accepted_30d ?? 0}`,
    `Acceptance rate: ${p.acceptance_rate_30d ?? 0}%`
  ].join("\\n");
}
async function loadInstallStats() {
  const status = $("install-stats-status");
  const cards = $("install-stats-cards");
  const daily = $("install-stats-daily");
  const csvButton = $("export-install-stats");
  const copyButton = $("copy-install-summary");
  const shareButton = $("share-install-summary");
  status.textContent = "Loading install statistics…";
  cards.hidden = true;
  daily.replaceChildren();
  [csvButton, copyButton, shareButton].forEach(b => b.disabled = true);
  try {
    const result = await rpc("install_report");
    if (!result || typeof result !== "object") throw new Error("The report returned no usable data.");
    installStatsData = result;
    const values = [
      ["install-total", result.total_installs],
      ["install-today", result.installs_today],
      ["install-seven", result.installs_7d],
      ["install-thirty", result.installs_30d],
      ["install-active", result.active_installs_30d]
    ];
    values.forEach(([id, value]) => $(id).textContent = Number(value || 0).toLocaleString("en-KE"));
    $("install-rate").textContent = Number(result.acceptance_rate_30d || 0).toFixed(1) + "%";
    $("install-prompt-counts").textContent = `${Number(result.prompts_accepted_30d || 0)} accepted of ${Number(result.prompts_shown_30d || 0)} shown in 30 days`;
    const rows = Array.isArray(result.daily) ? result.daily : [];
    daily.replaceChildren(rows.length
      ? table(["Date", "Installs", "Cumulative (30-day series)"], rows.map(r => [r.date, r.installs, r.cumulative_30d]))
      : el("p", "No daily install data is available yet."));
    cards.hidden = false;
    status.textContent = "Install statistics loaded from the protected report function.";
    [csvButton, copyButton, shareButton].forEach(b => b.disabled = false);
  } catch (error) {
    status.textContent = genericError(error, "Could not load install statistics. Confirm the Union Test migration and Platform Admin permissions.");
  }
}
$("refresh-install-stats").addEventListener("click", loadInstallStats);
$("export-install-stats").addEventListener("click", () => {
  if (!installStatsData) return;
  const rows = [["date", "installs", "cumulative_30d"], ...(installStatsData.daily || []).map(r => [r.date, r.installs, r.cumulative_30d])];
  const csv = rows.map(row => row.map(value => '"' + String(value ?? "").replace(/"/g, '""') + '"').join(",")).join("\\r\\n");
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a"); a.href = url; a.download = "timau-union-install-stats.csv"; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
$("copy-install-summary").addEventListener("click", async () => {
  if (!installStatsData) return;
  try { await navigator.clipboard.writeText(installSummary(installStatsData)); $("install-stats-status").textContent = "Summary copied."; }
  catch (_) { $("install-stats-status").textContent = "Clipboard access is unavailable in this browser."; }
});
$("share-install-summary").addEventListener("click", () => {
  if (installStatsData) window.open("https://wa.me/?text=" + encodeURIComponent(installSummary(installStatsData)), "_blank", "noopener,noreferrer");
});

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
      const displayName = item.display_name && item.display_name !== "Member" ? item.display_name : "Name not provided";
      return [displayName, item.email || "", item.email_verified ? "Verified" : "Not verified", item.requested_at ? new Date(item.requested_at).toLocaleString() : "—", item.role || "No role", cell];
    });
    container.replaceChildren(table(["Name", "Email", "Email verification", "Requested", "Active role", "Admin actions"], rendered));
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
  if (event === "PASSWORD_RECOVERY") {
    queueMicrotask(() => showRecoveryForm());
  } else if (event === "SIGNED_OUT" || !session) {
    if (!recoveryMode) resetPanels();
  } else if (event === "SIGNED_IN" || event === "TOKEN_REFRESHED" || event === "USER_UPDATED") {
    if (!recoveryMode) queueMicrotask(() => loadAccess());
  }
});

(async () => {
  try {
    // Supabase processes recovery tokens from the URL during client startup.
    // Yield briefly so its PASSWORD_RECOVERY event/session can be established
    // before deciding whether to show the normal sign-in panel.
    await new Promise(resolve => setTimeout(resolve, 250));
    const session = await currentSession();
    if (recoveryRequestedInUrl() && session) showRecoveryForm();
    else if (session) await loadAccess();
    else if (recoveryRequestedInUrl()) {
      resetPanels();
      message("This recovery link has not established a valid session. Open the newest reset email link again, and make sure it opens the /app member-access page.", "error");
    } else { resetPanels(); message("Sign in or create an account to continue."); }
  } catch (error) {
    console.error("Timau Union FC access initialization failed:", error);
    message("Could not connect to the access service. Check your connection and try again.", "error");
  }
})();
