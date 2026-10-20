import { createClient } from "https://esm.sh/@supabase/supabase-js@2.58.0";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./supabase-config.js";
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
const form = document.querySelector("#login-form"), statusBox = document.querySelector("#status-message"), submitButton = document.querySelector("#submit-button");
function showStatus(message, kind = "info") { statusBox.textContent = message; statusBox.dataset.kind = kind; statusBox.hidden = false; }
function setBusy(busy) { submitButton.disabled = busy; submitButton.textContent = busy ? "Checking access…" : "Sign in securely"; }
async function checkCurrentMembership(user) {
  const { data: membership, error } = await supabase.from("club_memberships").select("id,status").eq("user_id", user.id).maybeSingle();
  if (error) throw new Error("The club database is not ready or could not be reached. No access has been granted.");
  if (!membership || membership.status !== "active") throw new Error("This account does not have active club membership. Contact the Chairman if you believe this is a mistake.");
  const { data: roles, error: roleError } = await supabase.from("role_assignments").select("role_key").eq("membership_id", membership.id).is("revoked_at", null);
  if (roleError) throw new Error("Your role could not be verified. Access has been denied until the club system is available.");
  if (!roles || roles.length === 0) throw new Error("No active club role is assigned to this account. Contact the Chairman.");
}
async function routeIfAuthorised(user) {
  try { await checkCurrentMembership(user); window.location.replace("./dashboard.html"); }
  catch (error) { await supabase.auth.signOut(); showStatus(error.message || "Access could not be verified. Please try again later.", "error"); form.hidden = false; }
}
form.addEventListener("submit", async (event) => {
  event.preventDefault(); showStatus("Signing in and verifying your club membership…"); setBusy(true);
  try {
    const email = String(form.email.value || "").trim().toLowerCase(), password = String(form.password.value || "");
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error || !data.user) { showStatus("Sign-in failed. Check your details or confirm that your invitation has been accepted.", "error"); return; }
    await routeIfAuthorised(data.user);
  } catch (error) { showStatus(error.message || "Unable to connect securely. Please try again.", "error"); }
  finally { setBusy(false); }
});
(async () => {
  try {
    const { data, error } = await supabase.auth.getSession(); if (error) throw error;
    if (data.session?.user) { form.hidden = false; await routeIfAuthorised(data.session.user); return; }
    showStatus("Secure sign-in is configured. Only invited accounts with active membership and a current role may continue."); form.hidden = false;
  } catch { showStatus("The sign-in service could not be reached. No access has been granted. Please try again later.", "error"); form.hidden = false; }
})();
