import {createClient} from "https://esm.sh/@supabase/supabase-js@2";

const db=createClient("https://owvvimydkjsjlrmnzvdi.supabase.co","sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF",{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=s=>document.querySelector(s);
const roleSet=roles=>new Set(Array.isArray(roles)?roles:[]);
const addStyle=()=>{
 if($("#private-nav-styles"))return;
 const style=document.createElement("style");
 style.id="private-nav-styles";
 style.textContent=`
 .site-header .header-inner{display:flex;align-items:center;justify-content:space-between;gap:.65rem;min-height:68px;flex-wrap:nowrap}
 .site-header .brand{display:flex;align-items:center;gap:.55rem;min-width:0;flex:1 1 auto}
 .site-header .brand-mark{width:40px;height:40px;flex:0 0 40px}
 .site-header .brand-copy{min-width:0}
 .site-header .brand-copy strong{display:block;white-space:nowrap;font-size:clamp(.78rem,3.6vw,.95rem);letter-spacing:0}
 .site-header .brand-copy small{display:none!important}
 .site-header .access-actions,.site-header .header-actions{display:flex;align-items:center;justify-content:flex-end;gap:0;flex:0 0 auto;min-width:0}
 .site-header .access-actions>a,.site-header .header-actions>a{display:none!important}
 .site-header #signout,.site-header #sign-out{flex:0 0 auto;min-height:40px;padding:.5rem .7rem;white-space:nowrap;font-size:.88rem}
 .private-workspace-tabs{display:flex;flex-wrap:wrap;align-items:center;gap:.5rem;margin:0 auto 1.15rem;padding:.2rem 0 .85rem;width:100%;max-width:1200px}
 .private-workspace-tabs a,.private-workspace-tabs button{display:inline-flex;align-items:center;justify-content:center;min-height:42px;padding:.55rem .85rem;border:1px solid #171717;border-radius:8px;background:#171717;color:#fff;font:inherit;font-size:.9rem;font-weight:750;line-height:1.2;text-align:center;text-decoration:none;cursor:pointer;white-space:normal}
 .private-workspace-tabs a:hover,.private-workspace-tabs button:hover{background:#333;color:#fff}
 .private-workspace-tabs a[aria-current=page],.private-workspace-tabs button[aria-pressed=true]{background:#c8102e!important;border-color:#c8102e!important;color:#fff!important}
 .private-workspace-tabs a:focus-visible,.private-workspace-tabs button:focus-visible{outline:3px solid #c8102e;outline-offset:2px}
 .private-workspace-tabs [data-nav-type].ws-hidden{display:none!important}
 .private-workspace-tabs .ws-tabs,.private-workspace-tabs .coach-tabs,.private-workspace-tabs .tw-tabs,.private-workspace-tabs .sec-tabs,.private-workspace-tabs .media-tabs,.private-workspace-tabs .sl-tabs,.private-workspace-tabs .sp-tabs{display:contents!important;margin:0!important;padding:0!important;width:auto!important;max-width:none!important}
 @media(max-width:380px){.site-header .header-inner{gap:.35rem}.site-header .brand{gap:.4rem}.site-header .brand-mark{width:34px;height:34px;flex-basis:34px}.site-header .brand-copy strong{font-size:.76rem}.site-header #signout,.site-header #sign-out{padding:.45rem .55rem;font-size:.82rem}.private-workspace-tabs{gap:.4rem}.private-workspace-tabs a,.private-workspace-tabs button{min-height:40px;padding:.5rem .65rem;font-size:.85rem}}
 `;
 document.head.append(style);
};
const link=(label,href,active=false)=>{
 const a=document.createElement("a");a.className="button button-dark";a.textContent=label;a.href=href;
 if(active)a.setAttribute("aria-current","page");
 return a;
};
const sections=[
 {label:"Players",type:"player",roles:["team_manager","secretary"]},
 {label:"Fixtures & results",type:"fixture",roles:["team_manager","secretary"]},
 {label:"News",type:"news",roles:["media_team","secretary"]},
 {label:"Sponsors",type:"sponsor",roles:["sponsor_lead","secretary"]},
 {label:"Activities",type:"activity",roles:["team_manager","secretary"]}
];
const pages=[
 {label:"Club workspace",href:"workspace.html",roles:["team_manager","secretary","treasurer","coach","media_team","sponsor_lead","chairman","player_welfare"],admin:true},
 {label:"Coach workspace",href:"coach.html",roles:["coach"]},
 {label:"Secretary workspace",href:"secretary.html",roles:["secretary"]},
 {label:"Treasurer workspace",href:"treasurer.html",roles:["treasurer","chairman","secretary","vice_chairman","sponsor","sponsor_lead","team_manager","coach","player"]},
 {label:"Media Team",href:"media.html",roles:["media_team"]},
 {label:"Sponsor Lead",href:"sponsor-lead.html",roles:["sponsor_lead"]},
 {label:"Sponsor portal",href:"sponsor.html",roles:["sponsor"]},
 {label:"Sponsor account links",href:"sponsor-links.html",roles:["sponsor_lead"]},
 {label:"Kit & equipment",href:"kit.html",roles:["team_manager","coach","assistant_coach","secretary"]},
 {label:"Home attendance",href:"home-attendance.html",roles:["team_manager","secretary","chairman","vice_chairman","treasurer","coach","media_team","sponsor_lead"]},
 {label:"Monthly sponsor report",href:"monthly-sponsor-report.html",roles:["admin","chairman","treasurer","secretary","media_team","sponsor"]},
 {label:"Public website",href:"../index.html",roles:[],publicLink:true},
 {label:"Member access",href:"index.html",roles:[],memberAccess:true}
];
function currentPage(){return location.pathname.split("/").pop()||"workspace.html";}
function buildTabs(roles,isAdmin,isPlatformAdmin){
 const main=$("main");if(!main)return;
 const current=currentPage(),isWorkspace=current==="workspace.html";
 const localSpec={
  "workspace.html":{selector:".ws-tabs",gate:"#workspace"},
  "coach.html":{selector:".coach-tabs",gate:"#dashboard"},
  "treasurer.html":{selector:".tw-tabs",gate:"#dashboard"},
  "secretary.html":{selector:".sec-tabs",gate:"#dashboard"},
  "media.html":{selector:".media-tabs",gate:"#workspace"},
  "sponsor-lead.html":{selector:".sl-tabs"},
  "sponsor.html":{selector:".sp-tabs",gate:"#portal"}
 }[current];
 const canUseWorkspace=()=>{
  if(isPlatformAdmin||roles.has("chairman"))return true;
  if(roles.has("sponsor"))return false;
  if(roles.has("coach")&&!roles.has("team_manager")&&!roles.has("secretary")&&!roles.has("treasurer")&&!roles.has("media_team")&&!roles.has("sponsor_lead")&&!roles.has("player_welfare"))return false;
  if(roles.has("media_team")&&roles.size===1)return false;
  if(roles.has("sponsor_lead")&&roles.size===1)return false;
  if(roles.has("treasurer")&&!roles.has("secretary")&&!roles.has("team_manager")&&!roles.has("coach")&&!roles.has("media_team")&&!roles.has("sponsor_lead")&&!roles.has("player_welfare")&&!roles.has("player"))return false;
  return roles.has("team_manager")||roles.has("secretary")||roles.has("player_welfare")||roles.has("coach")||roles.has("media_team")||roles.has("sponsor_lead")||roles.has("treasurer");
 };
 const nav=document.createElement("nav");nav.className="private-workspace-tabs";nav.setAttribute("aria-label","Private workspace navigation");
 const localNav=localSpec?$(localSpec.selector):null;
 const localLabels=new Set(localNav?[...localNav.querySelectorAll("button")].map(b=>(b.textContent||"").trim().toLowerCase()):[]);
 const allowed=(entry)=>{
  if(entry.publicLink||entry.memberAccess)return true;
  if(entry.href==="sponsor.html")return roles.has("sponsor");
  if(entry.href==="sponsor-links.html")return roles.has("sponsor_lead")||isAdmin;
  if(entry.href==="workspace.html")return canUseWorkspace()&&(isAdmin||entry.roles.some(r=>roles.has(r)));
  return isAdmin||entry.roles.some(r=>roles.has(r));
 };
 if(canUseWorkspace()&&!isWorkspace){
  for(const s of sections){
   if(!(isAdmin||s.roles.some(r=>roles.has(r))))continue;
   if(localLabels.has(s.label.toLowerCase()))continue;
   if(current==="sponsor-lead.html"&&s.type==="sponsor")continue;
   nav.append(link(s.label,"./workspace.html?type="+encodeURIComponent(s.type)));
  }
 }
 for(const p of pages){
  if(!allowed(p))continue;
  const target=p.href.split("?")[0];
  nav.append(link(p.label,"./"+p.href,current===target));
 }
 main.insertBefore(nav,main.firstChild);
 if(localSpec){
  const moveLocalNav=()=>{
   const local=$(localSpec.selector),gate=localSpec.gate?$(localSpec.gate):null;
   if(!local||local.dataset.sharedNavigationMoved)return false;
   if(gate&&(gate.hidden||["ws-hidden","coach-hidden","tw-hidden","sec-hidden","media-hidden","sp-hidden"].some(c=>gate.classList.contains(c))))return false;
   local.dataset.sharedNavigationMoved="true";
   local.classList.add("private-nav-rehomed");
   nav.insertBefore(local,nav.firstChild);
   return true;
  };
  if(!moveLocalNav()){
   const observer=new MutationObserver(()=>{if(moveLocalNav())observer.disconnect()});
   observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:["class","hidden"]});
  }
 }
}
async function setup(){
 addStyle();
 const root=$(".site-header .access-actions, .site-header .header-actions");
 if(root){
  const signout=$("#signout")||$("#sign-out");
  root.querySelectorAll("a").forEach(a=>a.remove());
  [...root.children].forEach(child=>{if(child!==signout)child.remove()});
  if(signout){signout.textContent="Sign out";signout.setAttribute("aria-label","Sign out");}
 }
 const {data:{session}}=await db.auth.getSession();
 if(!session)return;
 const {data,error}=await db.rpc("club_get_workspace_bundle");
 if(error||!data)return;
 const roles=roleSet(data.roles),isPlatformAdmin=Boolean(data.is_platform_admin),isAdmin=isPlatformAdmin||roles.has("chairman");
 buildTabs(roles,isAdmin,isPlatformAdmin);
}
setup().catch(()=>{});
