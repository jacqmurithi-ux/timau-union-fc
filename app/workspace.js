import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabase = createClient("https://owvvimydkjsjlrmnzvdi.supabase.co","sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF",{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);
const labels={
 player:{title:"Player",plural:"Players",fields:[["name","Player name",true],["position","Position",false],["bio","Player profile / notes",false],["squad_number","Squad number",false]]},
 fixture:{title:"Fixture or result",plural:"Fixtures & results",fields:[["opponent","Opponent",true],["match_date","Date and kick-off (verified)",true],["venue","Venue",false],["result","Result or match status",false]]},
 news:{title:"News item",plural:"News",fields:[["title","Headline",true],["summary","Short summary",true],["body","Full story",false],["category","Category",false]]},
 sponsor:{title:"Sponsor or partner",plural:"Sponsors",fields:[["name","Sponsor / partner name",true],["support_type","Support type",false],["details","Approved public description",false],["website","Website or official link",false]]},
 activity:{title:"Club activity",plural:"Activities",fields:[["title","Activity title",true],["date","Date and time",false],["location","Location",false],["details","Details",false]]}
};
let role=null, records=[], activeType="player", editingId=null, canApprove=false;
function message(text,kind="info"){const n=$("notice");n.textContent=text;n.dataset.kind=kind;}
function node(tag,text,cls){const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);if(cls)e.className=cls;return e;}
function btn(text,fn){const b=node("button",text,"button button-dark");b.type="button";b.addEventListener("click",fn);return b;}
function fieldKey(type,index){return labels[type].fields[index][0];}
function setType(type){
 activeType=type;editingId=null;$("record-form").reset();
 document.querySelectorAll("[data-type]").forEach(b=>b.setAttribute("aria-pressed",String(b.dataset.type===type)));
 const cfg=labels[type];$("form-heading").textContent="Add "+cfg.title.toLowerCase();$("list-heading").textContent=cfg.plural+" records";
 cfg.fields.forEach((f,i)=>{const lab=$("field-"+["one","two","three","four"][i]+"-label");const old=$("field-"+["one","two","three","four"][i]);lab.firstChild.textContent=f[1];old.required=f[2];old.maxLength= f[0]==="body"||f[0]==="details"||f[0]==="bio"?3000:500;old.value="";old.placeholder=f[1];});
 $("field-three").tagName==="TEXTAREA"?null:null;
 renderRecords();
}
function formData(){const out={};labels[activeType].fields.forEach((f,i)=>{out[f[0]]=$("field-"+["one","two","three","four"][i]).value.trim();});return out;}
function startEdit(r){editingId=r.id;setType(r.record_type);editingId=r.id;const cfg=labels[activeType];cfg.fields.forEach((f,i)=>{$("field-"+["one","two","three","four"][i]).value=r.data?.[f[0]]??"";});$("form-heading").textContent="Edit "+cfg.title.toLowerCase();window.scrollTo({top:0,behavior:"smooth"});}
function renderRecords(){
 const root=$("records");root.replaceChildren();const list=records.filter(r=>r.record_type===activeType);
 if(!list.length){root.append(node("p","No records of this type yet. Create a record to start the club's verified information register.","workspace-small"));return;}
 list.forEach(r=>{
  const card=node("article",null,"workspace-record"),head=node("div",null,"workspace-record-head");
  const cfg=labels[r.record_type],title=r.data?.title||r.data?.name||r.data?.opponent||cfg.title;
  head.append(node("strong",title),node("span",(r.publication_status||"draft").toUpperCase()));card.append(head);
  const summary=r.data?.summary||r.data?.position||r.data?.match_date||r.data?.support_type||r.data?.date||r.data?.venue;
  if(summary)card.append(node("p",summary));
  const detail=r.data?.body||r.data?.bio||r.data?.details||r.data?.result;
  if(detail)card.append(node("p",detail));
  if(r.publication_status==="approved")card.append(node("p","Approved for public display.","workspace-small"));
  const actions=node("div",null,"workspace-actions");
  actions.append(btn("Edit",()=>startEdit(r)));
  if(canApprove && r.publication_status!=="approved")actions.append(btn("Approve for public",()=>setStatus(r.id,"approved")));
  if(canApprove && r.publication_status==="approved")actions.append(btn("Unpublish to draft",()=>setStatus(r.id,"draft")));
  if(canApprove && r.publication_status!=="archived")actions.append(btn("Archive",()=>setStatus(r.id,"archived")));
  card.append(actions);root.append(card);
 });
}
async function load(){
 message("Refreshing records from the production database…");
 try{
  const {data,error}=await supabase.rpc("club_get_workspace_bundle");if(error)throw error;
  role=data.role;canApprove=Boolean(data.can_approve);records=Array.isArray(data.records)?data.records:[];
  $("role-badge").textContent="ROLE · "+String(role).replaceAll("_"," ").toUpperCase();
  $("workspace").classList.remove("workspace-hidden");renderRecords();
  message("Workspace connected. Changes are saved through protected database functions.","success");
 }catch(e){
  $("workspace").classList.add("workspace-hidden");
  message("Workspace is not available yet. The Phase 2 database migration must be reviewed and applied, and your account must have an approved active club role. "+(e?.message||""),"error");
  const link=node("a","Return to member access");link.href="./index.html";link.className="text-link";$("notice").append(" ");$("notice").append(link);
 }
}
async function setStatus(id,status){
 const reason=window.prompt("Required reason for "+status+" (minimum 3 characters):");if(reason===null)return;
 if(reason.trim().length<3){message("Enter a reason of at least 3 characters.","error");return;}
 try{const {error}=await supabase.rpc("club_set_publication_status",{_record_id:id,_new_status:status,_reason:reason.trim()});if(error)throw error;message("Publication status updated.","success");await load();}
 catch(e){message("Could not change publication status. "+(e?.message||""),"error");}
}
$("record-form").addEventListener("submit",async ev=>{
 ev.preventDefault();const data=formData();
 if(labels[activeType].fields.some(f=>f[2]&&!String(data[f[0]]||"").trim())){message("Complete all required fields.","error");return;}
 const submit=$("record-form").querySelector('[type="submit"]');submit.disabled=true;
 try{const {error}=await supabase.rpc("club_save_record",{_record_id:editingId,_record_type:activeType,_data:data});if(error)throw error;
 editingId=null;$("record-form").reset();$("form-heading").textContent="Add "+labels[activeType].title.toLowerCase();message("Saved as draft. An authorised approver must approve it before public display.","success");await load();}
 catch(e){message("Save failed; no success was reported. "+(e?.message||""),"error");}
 finally{submit.disabled=false;}
});
$("cancel-edit").addEventListener("click",()=>{editingId=null;$("record-form").reset();$("form-heading").textContent="Add "+labels[activeType].title.toLowerCase();});
$("refresh").addEventListener("click",load);
document.querySelectorAll("[data-type]").forEach(b=>b.addEventListener("click",()=>setType(b.dataset.type)));
$("signout").addEventListener("click",async()=>{const {error}=await supabase.auth.signOut();if(error)message("Sign out failed. Please retry.","error");else window.location.href="./index.html";});
supabase.auth.onAuthStateChange((event,session)=>{if(event==="SIGNED_OUT"||!session)window.location.href="./index.html";});
setType("player");
const {data:{session}}=await supabase.auth.getSession();
if(!session){window.location.href="./index.html";}else await load();
