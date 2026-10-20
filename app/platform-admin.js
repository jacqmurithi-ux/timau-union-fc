import { createClient } from "https://esm.sh/@supabase/supabase-js@2.58.0";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./supabase-config.js";
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
const statusBox = document.querySelector("#status-message"), list = document.querySelector("#account-list");
const refreshButton = document.querySelector("#refresh-button"), signOutButton = document.querySelector("#sign-out");
const roleOptions = [
 ["chairman","Chairman"],["vice_chairman","Vice Chairman"],["secretary","Secretary"],["team_manager","Team Manager"],
 ["treasurer","Treasurer"],["coach","Coach"],["sponsor_lead","Sponsor Lead"],["media_team","Media Team"]
];
function status(message, kind="info") { statusBox.textContent = message; statusBox.dataset.kind = kind; }
function el(tag, className, value) { const node = document.createElement(tag); if (className) node.className = className; if (value !== undefined) node.textContent = value; return node; }
function makeRoleSelect() {
 const select = document.createElement("select"); select.setAttribute("aria-label","Role to assign");
 select.style.cssText = "width:100%;max-width:280px;padding:10px;border:1px solid var(--border);border-radius:8px;background:var(--surface);color:var(--text)";
 for (const [value,label] of roleOptions) { const opt=document.createElement("option"); opt.value=value; opt.textContent=label; select.append(opt); }
 return select;
}
async function invoke(action, extra={}) {
 const { data, error } = await supabase.functions.invoke("club-admin", { body: { action, ...extra } });
 if (error) {
  let message = "The secure administration request failed.";
  try { const body = await error.context?.json(); if (body?.error) message = body.error.replaceAll("_"," "); } catch {}
  throw new Error(message);
 }
 if (!data) throw new Error("The backend returned no confirmation.");
 return data;
}
function renderAccounts(accounts) {
 list.replaceChildren();
 if (!accounts.length) { list.append(el("p","", "No registered accounts were returned.")); return; }
 for (const account of accounts) {
  const card=el("article","feature-card"); card.style.cssText="color:var(--text);background:var(--surface);border:1px solid var(--border);border-top:3px solid var(--red);padding:16px";
  const heading=el("h3","",account.display_name || account.email || "Unnamed account"); heading.style.marginTop="0";
  const meta=el("p","",account.email || "No email address"); meta.style.cssText="overflow-wrap:anywhere;color:var(--muted)";
  const statusLine=el("p","", "Account: "+String(account.membership_status).replaceAll("_"," ")+" · Email "+(account.email_confirmed?"verified":"not verified"));
  const currentRoles=el("p","", "Current role(s): "+(account.roles.length?account.roles.map(x=>x.replaceAll("_"," ")).join(", "):"none"));
  card.append(heading,meta,statusLine,currentRoles);
  if (account.membership_status === "platform_admin") {
   const note=el("p","", "Platform administrator account — self-approval and self-assignment are disabled."); note.style.color="var(--muted)"; card.append(note);
  } else if (account.membership_status === "pending_approval" || account.membership_status === "invited") {
   const select=makeRoleSelect(), noteInput=document.createElement("input");
   noteInput.type="text"; noteInput.maxLength=500; noteInput.placeholder="Approval note (optional)";
   noteInput.setAttribute("aria-label","Approval note"); noteInput.style.cssText="width:100%;padding:10px;margin-top:10px;border:1px solid var(--border);border-radius:8px;background:var(--surface);color:var(--text)";
   const button=el("button","button button-dark", "Approve access & assign role"); button.type="button"; button.disabled=!account.email_confirmed; button.style.marginTop="10px";
   if (!account.email_confirmed) { const hint=el("p","", "Email verification is required before approval."); hint.style.color="var(--muted)"; card.append(hint); }
   button.addEventListener("click",async()=>{ button.disabled=true; status("Approving account and assigning role…"); try { await invoke("platform_approve_signup",{user_id:account.user_id,role:select.value,note:noteInput.value.trim()||null}); status("Account approved and role assigned."); await loadAccounts(false); } catch(e) { status(e.message,"error"); button.disabled=false; } });
   card.append(select,noteInput,button);
  } else if (account.membership_status === "active") {
   const controls=el("div",""); controls.style.cssText="display:flex;gap:8px;align-items:center;flex-wrap:wrap";
   const select=makeRoleSelect(), noteInput=document.createElement("input"); noteInput.type="text"; noteInput.maxLength=500; noteInput.placeholder="Role-change note (optional)"; noteInput.setAttribute("aria-label","Role change note"); noteInput.style.cssText="width:100%;padding:10px;margin:10px 0;border:1px solid var(--border);border-radius:8px;background:var(--surface);color:var(--text)";
   const assign=el("button","button button-dark","Assign selected role"); assign.type="button";
   assign.addEventListener("click",async()=>{ assign.disabled=true; status("Assigning role…"); try { await invoke("platform_assign_role",{user_id:account.user_id,role:select.value,note:noteInput.value.trim()||null}); status("Role assignment saved."); await loadAccounts(false); } catch(e) { status(e.message,"error"); assign.disabled=false; } });
   controls.append(select,assign); card.append(controls,noteInput);
   for(const role of account.roles) {
    if(role==="chairman") continue;
    const revoke=el("button","button button-dark","Revoke "+role.replaceAll("_"," ")); revoke.type="button"; revoke.style.margin="6px 6px 0 0";
    revoke.addEventListener("click",async()=>{ if(!window.confirm("Revoke the "+role.replaceAll("_"," ")+" role for "+(account.email||"this account")+"?")) return; revoke.disabled=true; status("Revoking role…"); try { await invoke("platform_revoke_role",{user_id:account.user_id,role,note:"Revoked by platform administrator"}); status("Role revoked."); await loadAccounts(false); } catch(e) { status(e.message,"error"); revoke.disabled=false; } });
    card.append(revoke);
   }
  } else {
   const note=el("p","", "This membership is suspended or revoked. Restore/reactivation requires a separate reviewed lifecycle action."); note.style.color="var(--muted)"; card.append(note);
  }
  list.append(card);
 }
}
async function loadAccounts(showLoading=true) {
 if(showLoading) status("Loading registered accounts…");
 refreshButton.disabled=true;
 try {
  const data=await invoke("platform_list_accounts");
  if(!Array.isArray(data.accounts)) throw new Error("The backend returned an invalid account list.");
  renderAccounts(data.accounts);
  status(data.truncated?"Showing the latest 200 accounts. Refine account-list pagination before a large rollout.":"Account list loaded. Changes are checked by the backend.", "success");
 } catch(e) {
  list.replaceChildren(); status("Platform access could not be verified or the backend is not ready: "+e.message,"error");
  if(/platform admin required|platform_admin_required/i.test(e.message)) window.location.replace("./index.html");
 } finally { refreshButton.disabled=false; }
}
refreshButton.addEventListener("click",()=>loadAccounts());
signOutButton.addEventListener("click",async()=>{ signOutButton.disabled=true; await supabase.auth.signOut(); window.location.replace("./index.html"); });
(async()=>{
 const {data,error}=await supabase.auth.getSession();
 if(error||!data.session?.user){window.location.replace("./index.html");return;}
 await loadAccounts();
})();
