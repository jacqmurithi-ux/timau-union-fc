import { createClient } from "https://esm.sh/@supabase/supabase-js@2.58.0";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./supabase-config.js";
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
const loginForm = document.querySelector("#login-form"), signupForm = document.querySelector("#signup-form");
const statusBox = document.querySelector("#status-message"), loginButton = document.querySelector("#submit-button"), signupButton = document.querySelector("#signup-button");
const showLoginButton = document.querySelector("#show-login"), showSignupButton = document.querySelector("#show-signup");
function showStatus(message, kind = "info") { statusBox.textContent = message; statusBox.dataset.kind = kind; statusBox.hidden = false; }
function switchMode(mode) {
 const signup = mode === "signup"; loginForm.hidden = signup; signupForm.hidden = !signup;
 showLoginButton.setAttribute("aria-pressed", String(!signup)); showSignupButton.setAttribute("aria-pressed", String(signup));
 showStatus(signup ? "Create an account to request access. This will not assign club membership or a role." : "Sign in with your verified account. Membership and role are checked separately.");
}
function setBusy(button, busy, label) { button.disabled = busy; button.textContent = busy ? "Please wait…" : label; }
async function checkCurrentMembership(user) {
 const { data: membership, error } = await supabase.from("club_memberships").select("id,status").eq("user_id", user.id).maybeSingle();
 if (error) throw new Error("The club database is not ready or could not be reached. No access has been granted.");
 if (!membership || membership.status !== "active") throw new Error("Your account exists, but active club membership has not been approved yet.");
 const { data: roles, error: roleError } = await supabase.from("role_assignments").select("role_key").eq("membership_id", membership.id).is("revoked_at", null);
 if (roleError) throw new Error("Your role could not be verified. Access has been denied until the club system is available.");
 if (!roles || roles.length === 0) throw new Error("No active club role is assigned to this account. Contact the Chairman.");
}
async function routeIfAuthorised(user) {
 try {
  // A separately bootstrapped platform administrator does not need a club membership.
  const { data: platformData, error: platformError } = await supabase.functions.invoke("club-admin", { body: { action: "platform_list_accounts" } });
  if (!platformError && Array.isArray(platformData?.accounts)) { window.location.replace("./platform-admin.html"); return; }
  await checkCurrentMembership(user); window.location.replace("./dashboard.html");
 }
 catch (error) { await supabase.auth.signOut(); showStatus(error.message || "Access could not be verified. Please try again later.", "error"); switchMode("login"); }
}
showLoginButton.addEventListener("click", () => switchMode("login"));
showSignupButton.addEventListener("click", () => switchMode("signup"));
loginForm.addEventListener("submit", async (event) => {
 event.preventDefault(); setBusy(loginButton, true, "Sign in securely"); showStatus("Signing in and verifying your club membership…");
 try {
  const email = String(loginForm.elements.email.value || "").trim().toLowerCase(), password = String(loginForm.elements.password.value || "");
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) { showStatus("Sign-in failed. Check your details or confirm your email address.", "error"); return; }
  await routeIfAuthorised(data.user);
 } catch (error) { showStatus(error.message || "Unable to connect securely. Please try again.", "error"); }
 finally { setBusy(loginButton, false, "Sign in securely"); }
});
signupForm.addEventListener("submit", async (event) => {
 event.preventDefault();
 const name = String(signupForm.elements.display_name.value || "").trim();
 const email = String(signupForm.elements.email.value || "").trim().toLowerCase();
 const password = String(signupForm.elements.password.value || "");
 const confirm = String(signupForm.elements.confirm_password.value || "");
 if (name.length < 2 || password.length < 8) { showStatus("Enter your full name and a password of at least 8 characters.", "error"); return; }
 if (password !== confirm) { showStatus("The passwords do not match.", "error"); return; }
 setBusy(signupButton, true, "Create account"); showStatus("Creating your authentication account…");
 try {
  const { data, error } = await supabase.auth.signUp({
   email, password, options: {
    emailRedirectTo: new URL("./index.html", window.location.href).href,
    data: { display_name: name }
   }
  });
  if (error) { showStatus(error.message || "Registration could not be completed. Please try again.", "error"); return; }
  // Never create a membership or assign a role from the public browser.
  if (data.session) await supabase.auth.signOut();
  signupForm.reset();
  showStatus("Registration submitted. Check your email for a verification message if required. Your account does not yet have club membership or a role. A platform administrator must approve access and assign your role.");
 } catch (error) { showStatus(error.message || "Registration service unavailable. Please try again later.", "error"); }
 finally { setBusy(signupButton, false, "Create account"); }
});
(async () => {
 try {
  const { data, error } = await supabase.auth.getSession(); if (error) throw error;
  if (data.session?.user) { await routeIfAuthorised(data.session.user); return; }
  switchMode("login");
 } catch { showStatus("The sign-in service could not be reached. No access has been granted. Please try again later.", "error"); switchMode("login"); }
})();
