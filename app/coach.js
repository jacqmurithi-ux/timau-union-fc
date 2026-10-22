import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const db=createClient("https://owvvimydkjsjlrmnzvdi.supabase.co","sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF",{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);
const schemas={
 training_plans:{title:"Training plan",fields:[["week_start","Week starting"],["session_date","Session date and time"],["objectives","Session objectives"],["drills","Drills per session"],["duration_minutes","Duration (minutes)"],["notes","Coach notes"]]},
 training_attendance:{title:"Training attendance",fields:[["session_date","Session date"],["player_name","Player name"],["attendance_status","Attendance status (present/late/absent)"],["coach_notes","Coach notes for this player"]]},
 match_selection:{title:"Match selection draft",fields:[["fixture","Fixture / opponent"],["match_date","Match date"],["formation","Formation"],["starting_xi","Starting XI (one player per line)"],["substitutes","Substitutes (one player per line)"],["player_roles","Role per player"],["coach_notes","Notes for Team Manager"]]},
 tactics_match_prep:{title:"Tactics & match preparation",fields:[["fixture","Fixture / opponent"],["opponent_notes","Opponent notes"],["game_plan","Game plan"],["set_pieces","Set pieces"],["notes","Additional notes"]]},
 player_performance:{title:"Player performance",fields:[["fixture","Fixture / match"],["player_name","Player name"],["rating","Rating (out of 10)"],["goals","Goals"],["assists","Assists"],["minutes_played","Minutes played"],["strengths","Strengths"],["development_areas","Development areas"]]},
 match_analysis:{title:"Match analysis",fields:[["fixture","Fixture / opponent"],["match_date","Match date"],["review","Post-match review"],["worked_well","What worked"],["to_fix","What to fix"],["notes","Follow-up notes"]]},
 player_development:{title:"Player development",fields:[["player_name","Player name"],["age_group","Age group (including youth/reserve)"],["targets","Individual targets"],["progress","Progress so far"],["next_review_date","Next review date"],["notes","Coach notes"]]}
};
let section="fixtures",roles=[],records=[],squad=[],fitness=[],discipline=[],fixtures=[],activities=[],editing=null,isAdmin=false;
const coach=()=>roles.includes("coach"),isChairman=()=>roles.includes("chairman");
const admin=()=>isAdmin||isChairman();
function note(s,kind="info"){$("notice").textContent=s;$("notice").dataset.kind=kind}
function el(tag,text,cls){const e=document.createElement(tag);if(text!==undefined&&text!==null)e.textContent=String(text);if(cls)e.className=cls;return e}
function button(text,fn){const b=el("button",text,"button button-dark");b.type="button";b.addEventListener("click",fn);return b}
function canEdit(){return admin()||coach()}
function readOnlySection(){return ["fixtures","activities","squad","fitness","discipline"].includes(section)}
function setSection(next){
 if(!schemas[next]&&!["fixtures","activities","squad","fitness","discipline"].includes(next))return;
 section=next;editing=null;$("coach-form").reset();$("coach-form").replaceChildren();
 document.querySelectorAll("[data-section]").forEach(b=>b.setAttribute("aria-pressed",String(b.dataset.section===section)));
 const readOnly=readOnlySection();$("form-panel").classList.toggle("coach-hidden",readOnly||!canEdit());
 $("save").classList.toggle("coach-hidden",readOnly||!canEdit());$("clear").classList.toggle("coach-hidden",readOnly||!canEdit());
 const titles={fixtures:"Fixtures & results",activities:"Activities",squad:"Squad list (read-only)",fitness:"Injuries & fitness (read-only)",discipline:"Discipline summary (read-only)"};
 $("list-heading").textContent=schemas[section]?.title||titles[section];$("form-heading").textContent="Add "+(schemas[section]?.title||"Coach record").toLowerCase();
 $("list-help").textContent=readOnly?"Read-only information. Squad administration, injury and discipline records remain owned by the Team Manager and welfare roles.":"Coach drafts are private until approved. The Team Manager submits the official team sheet.";
 if(schemas[section]&&canEdit())schemas[section].fields.forEach(([key,label])=>{
  const wrap=el("label",label);let input;
  if(["drills","objectives","notes","coach_notes","starting_xi","substitutes","player_roles","opponent_notes","game_plan","set_pieces","strengths","development_areas","review","worked_well","to_fix","targets","progress","coach_notes"].includes(key)){input=document.createElement("textarea");input.rows=3}
  else input=document.createElement("input");
  input.name=key;input.maxLength=5000;input.autocomplete="off";input.required=["session_date","player_name","fixture"].includes(key);wrap.append(input);$("coach-form").append(wrap);
 });
 render();
}
function recordTitle(r){const d=r.data||{};return d.fixture||d.player_name||d.session_date||d.week_start||d.title||"Coach record"}
function render(){
 const root=$("records");root.replaceChildren();let list=[];
 if(section==="squad")list=squad.map(p=>({data:{name:p.data?.name||"Unnamed player",position:p.data?.position,age_group:p.data?.age_group,availability_status:p.data?.availability_status,fitness_status:p.data?.fitness_status,squad_number:p.data?.squad_number},readOnly:true}));
 else if(section==="fitness")list=fitness.map(x=>({data:x,readOnly:true}));
 else if(section==="discipline")list=discipline.map(x=>({data:x,readOnly:true}));
 else if(section==="fixtures")list=fixtures.map(x=>({data:x.data||{},status:x.publication_status,readOnly:true}));
 else if(section==="activities")list=activities.map(x=>({data:x.data||{},status:x.publication_status,readOnly:true}));
 else list=records.filter(r=>r.section_key===section);
 if(!list.length){root.append(el("p","No records available yet. No sample or unverified data has been added.","coach-muted"));return}
 for(const r of list){
  const card=el("article",undefined,"coach-record"),head=el("div",undefined,"coach-record-top");
  head.append(el("strong",r.data?.name||recordTitle(r)),el("span",r.publication_status||r.status||"READ ONLY","coach-status"));card.append(head);
  Object.entries(r.data||{}).forEach(([k,v])=>{if(v===null||v===undefined||String(v).trim()==="")return;const label=k.replaceAll("_"," ");card.append(el("p",label+": "+String(v),"coach-muted"))});
  if(r.readOnly){root.append(card);continue}
  const actions=el("div",undefined,"coach-actions");
  if(canEdit()&&(coach()||admin()))actions.append(button("Edit draft",()=>editRecord(r)));
  if(admin()&&r.publication_status!=="approved")actions.append(button("Approve",()=>setStatus(r.id,"approved")));
  if(admin()&&r.publication_status==="approved")actions.append(button("Return to draft",()=>setStatus(r.id,"draft")));
  if(actions.childNodes.length)card.append(actions);root.append(card);
 }
}
function editRecord(r){editing=r.id;setSection(section);const data=r.data||{};for(const [key] of schemas[section].fields){const input=$("coach-form").elements.namedItem(key);if(input)input.value=data[key]||""}editing=r.id;$("form-heading").textContent="Edit "+schemas[section].title.toLowerCase()+" · save returns it to draft";window.scrollTo({top:0,behavior:"smooth"})}
async function setStatus(id,status){const reason=window.prompt("Admin/Chairman approval reason (minimum 3 characters):");if(reason===null)return;if(reason.trim().length<3){note("A reason of at least 3 characters is required.","error");return}try{const {error}=await db.rpc("coach_set_publication_status",{_record_id:id,_new_status:status,_reason:reason.trim()});if(error)throw error;note("Coach record status updated and audited.","success");await load()}catch(e){note("Publication change denied. "+(e?.message||""),"error")}}
async function load(){
 note("Checking role and loading Coach dashboard…");
 try{
  const {data:access,error:accessError}=await db.rpc("club_get_workspace_bundle");if(accessError)throw new Error("Could not verify your club role. "+(accessError.message||""));
  roles=Array.isArray(access?.roles)?access.roles:[];isAdmin=Boolean(access?.is_platform_admin)||roles.includes("chairman");
  if(!isAdmin&&!coach()){
   $("dashboard").classList.add("coach-hidden");
   note("This page is for Coaches and club administrators. Your current role does not have Coach dashboard access. Use the role-appropriate links in the navigation above.","error");
   return;
  }
  const {data,error}=await db.rpc("coach_get_dashboard");
  if(error){if(error.code==="42883"||error.code==="PGRST202")throw new Error("Coach database migration/functions are missing. Install the Coach migration, then refresh.");throw error;}
  roles=Array.isArray(data.roles)?data.roles:roles;isAdmin=Boolean(data.is_admin)||isAdmin;
  records=Array.isArray(data.records)?data.records:[];squad=Array.isArray(data.squad)?data.squad:[];fitness=Array.isArray(data.fitness)?data.fitness:[];discipline=Array.isArray(data.discipline)?data.discipline:[];
  const {data:bundle,error:bundleError}=await db.rpc("club_get_workspace_bundle");if(bundleError)throw bundleError;
  const base=Array.isArray(bundle.records)?bundle.records:[];
  fixtures=base.filter(r=>r.record_type==="fixture"&&r.publication_status!=="archived");
  activities=base.filter(r=>r.record_type==="activity"&&r.publication_status!=="archived");
  $("role-badge").textContent=isAdmin?"CHAIRMAN / PLATFORM ADMIN": "ROLE · "+roles.map(r=>r.replaceAll("_"," ").toUpperCase()).join(" / ");
  $("dashboard").classList.remove("coach-hidden");note("Connected. Coach records are isolated in the database; new and edited records remain drafts.","success");setSection(section);
 }catch(e){$("dashboard").classList.add("coach-hidden");note((e?.message||"Coach dashboard could not load. Check the Coach migration and your assigned role."),"error")}
}
$("coach-form").addEventListener("submit",async e=>{
 e.preventDefault();if(!schemas[section]||!canEdit()){note("This section is read-only.","error");return}
 const data={};for(const [key] of schemas[section].fields)data[key]=String($("coach-form").elements.namedItem(key)?.value||"").trim();
 if(schemas[section].fields.some(([key])=>["session_date","player_name","fixture"].includes(key))&&!Object.values(data).some(v=>v))return note("Complete the required field.","error");
 let reason=null;if(editing&&admin()&&!coach()){reason=window.prompt("Administrator override reason (minimum 3 characters):");if(reason===null||reason.trim().length<3)return note("A reason is required for administrator overrides.","error")}
 $("save").disabled=true;
 try{const {error}=await db.rpc("coach_save_record",{_record_id:editing,_section_key:section,_data:data,_reason:reason});if(error)throw error;editing=null;note("Saved as draft. Approval is required before publication.","success");await load()}catch(err){note("Save failed. "+(err?.message||""),"error")}finally{$("save").disabled=false}
});
$("clear").addEventListener("click",()=>{editing=null;$("coach-form").reset();$("form-heading").textContent="Add "+schemas[section].title.toLowerCase()});
$("refresh").addEventListener("click",load);document.querySelectorAll("[data-section]").forEach(b=>b.addEventListener("click",()=>setSection(b.dataset.section)));
$("signout").addEventListener("click",async()=>{const {error}=await db.auth.signOut();if(error)note("Sign out failed. Please retry.","error");else location.href="./index.html"});
db.auth.onAuthStateChange((event,session)=>{if(event==="SIGNED_OUT"||!session)location.href="./index.html"});
const {data:{session}}=await db.auth.getSession();if(!session)location.href="./index.html";else await load();
