import { createClient } from "https://esm.sh/@supabase/supabase-js@2.58.0";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./supabase-config.js";
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
const statusBox = document.querySelector("#dashboard-status"), card = document.querySelector("#account-card"), signOutButton = document.querySelector("#sign-out");
function deny(message) { statusBox.textContent = message; card.hidden = true; }
async function signOutAndReturn(message) { await supabase.auth.signOut(); deny(message); window.setTimeout(() => window.location.replace("./index.html"), 1600); }
signOutButton.addEventListener("click", async () => { signOutButton.disabled = true; await supabase.auth.signOut(); window.location.replace("./index.html"); });
(async () => {
 try {
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
  if (sessionError || !sessionData.session?.user) { window.location.replace("./index.html"); return; }
  const user = sessionData.session.user;
  const { data: membership, error: membershipError } = await supabase.from("club_memberships").select("id,status").eq("user_id", user.id).maybeSingle();
  if (membershipError) return await signOutAndReturn("Club membership could not be verified. Access denied.");
  if (!membership || membership.status !== "active") return await signOutAndReturn("Your club membership is not active. Access denied.");
  const [{ data: profile, error: profileError }, { data: roles, error: rolesError }] = await Promise.all([
   supabase.from("user_profiles").select("display_name").eq("user_id", user.id).maybeSingle(),
   supabase.from("role_assignments").select("role_key").eq("membership_id", membership.id).is("revoked_at", null)
  ]);
  if (rolesError || profileError) return await signOutAndReturn("Your profile or role could not be verified. Access denied.");
  if (!roles?.length) return await signOutAndReturn("No active club role is assigned. Access denied.");
  document.querySelector("#welcome-title").textContent = profile?.display_name ? "Welcome, " + profile.display_name : "Welcome to the club hub";
  document.querySelector("#role-list").textContent = "Verified role(s): " + roles.map(item => item.role_key.replace(/_/g, " ")).join(", ");
  statusBox.textContent = "Your active membership and role have been verified."; card.hidden = false;
 } catch { await signOutAndReturn("The club database could not verify your access. Access denied."); }
})();
