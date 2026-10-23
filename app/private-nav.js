import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import {PAGE_ACCESS,PAGE_HOME,PAGE_LABELS,ROLE_LABELS,SECTION_ACCESS} from "./role-navigation.js";

const db=createClient("https://owvvimydkjsjlrmnzvdi.supabase.co","sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF",{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=s=>document.querySelector(s);
const roleSet=roles=>new Set(Array.isArray(roles)?roles:[]);
const currentPage=()=>location.pathname.split("/").pop()||"workspace.html";
const readableRole=role=>ROLE_LABELS[role]||String(role||"").replaceAll("_"," ").replace(/\b\w/g,c=>c.toUpperCase());
const roleNames=roles=>[...roles].map(readableRole);
const isAllowed=(allowed,roles)=>allowed.some(role=>roles.has(role));
function homeFor(roles){
 const entry=PAGE_HOME.find(item=>isAllowed(item.roles,roles));
 return entry?.page||"index.html";
}
function addStyle(){
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
 .private-workspace-tabs a[aria-current=page]{background:#c8102e!important;border-color:#c8102e!important;color:#fff!important}
 .private-workspace-tabs a:focus-visible,.private-workspace-tabs button:focus-visible{outline:3px solid #c8102e;outline-offset:2px}
 .private-workspace-tabs [data-nav-type].ws-hidden{display:none!important}
 .private-workspace-tabs .ws-tabs,.private-workspace-tabs .coach-tabs,.private-workspace-tabs .tw-tabs,.private-workspace-tabs .sec-tabs,.private-workspace-tabs .media-tabs,.private-workspace-tabs .sl-tabs,.private-workspace-tabs .sp-tabs{display:contents!important;margin:0!important;padding:0!important;width:auto!important;max-width:none!important}
 .private-workspace-tabs .ws-tabs button[aria-pressed=true],.private-workspace-tabs .coach-tabs button[aria-pressed=true],.private-workspace-tabs .tw-tabs button[aria-pressed=true],.private-workspace-tabs .sec-tabs button[aria-pressed=true],.private-workspace-tabs .media-tabs button[aria-pressed=true],.private-workspace-tabs .sl-tabs button[aria-selected=true],.private-workspace-tabs .sp-tabs button[aria-selected=true]{background:#171717!important;border-color:#171717!important;color:#fff!important}
 @media(max-width:380px){.site-header .header-inner{gap:.35rem}.site-header .brand{gap:.4rem}.site-header .brand-mark{width:34px;height:34px;flex-basis:34px}.site-header .brand-copy strong{font-size:.76rem}.site-header #signout,.site-header #sign-out{padding:.45rem .55rem;font-size:.82rem}.private-workspace-tabs{gap:.4rem}.private-workspace-tabs a,.private-workspace-tabs button{min-height:40px;padding:.5rem .65rem;font-size:.85rem}}
 `;
 document.head.append(style);
}
function addNotice(message){
 const main=$("main");if(!main)return;
 let note=$("#private-nav-access-notice");
 if(!note){note=document.createElement("p");note.id="private-nav-access-notice";note.setAttribute("role","status");note.className="ws-note";main.insertBefore(note,main.children[1]||null);}
 note.textContent=message;
}
function filterLocalTabs(roles,page){
 const sectionMap=SECTION_ACCESS[page];
 const navs=[...document.querySelectorAll("main nav")].filter(nav=>!nav.classList.contains("private-workspace-tabs"));
 for(const nav of navs){
  const controls=[...nav.querySelectorAll("button[data-type],button[data-section],button[data-tab],button[data-legacy-type]")];
  if(!controls.length)continue;
  for(const button of controls){
   const key=button.dataset.type||button.dataset.section||button.dataset.tab||button.dataset.legacyType;
   if(!sectionMap)continue;
   const allowed=sectionMap[key]||[];
   const visible=isAllowed(allowed,roles);
   button.hidden=!visible;
   button.setAttribute("aria-hidden",String(!visible));
   button.tabIndex=visible?0:-1;
  }
 }
}
function buildTabs(roles,page){
 const main=$("main");if(!main)return;
 const nav=document.createElement("nav");nav.className="private-workspace-tabs";nav.setAttribute("aria-label","Workspace pages");
 const seen=new Set();
 for(const [href,allowed] of Object.entries(PAGE_ACCESS)){
  if(href==="index.html"||!isAllowed(allowed,roles)||seen.has(href))continue;
  seen.add(href);
  const a=document.createElement("a");a.className="button button-dark";a.textContent=PAGE_LABELS[href]||href;a.href="./"+href;
  if(page===href)a.setAttribute("aria-current","page");
  nav.append(a);
 }
 const localNavs=[...main.querySelectorAll(":scope > nav")].filter(n=>!n.classList.contains("private-workspace-tabs"));
 main.insertBefore(nav,main.firstChild);
 for(const local of localNavs)nav.append(local);
 filterLocalTabs(roles,page);
 const observer=new MutationObserver(()=>filterLocalTabs(roles,page));
 observer.observe(main,{subtree:true,childList:true});
}
function updateRoleLabels(roles,page){
 const badge=$("#role-badge");
 if(badge)badge.textContent="ROLE · "+(roles.size?roleNames(roles).join(" / "):"Platform Admin");
 const title=$("main h1");
 if(title&&page==="sponsor-lead.html"&&roles.has("sponsor_lead"))title.textContent="Sponsor Lead workspace";
 if(title&&page==="treasurer.html"&&!roles.has("treasurer")&&!roles.has("chairman")&&!roles.has("admin"))title.textContent=roleNames(roles)[0]+" workspace";
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
 const roles=roleSet(data.roles);
 if(Boolean(data.is_platform_admin))roles.add("admin");
 const page=currentPage();
 const allowed=PAGE_ACCESS[page];
 if(allowed&&!isAllowed(allowed,roles)){
  const home=homeFor(roles);
  location.replace("./"+home+(home.includes("?")?"&":"?")+"accessDenied=1");
  return;
 }
 updateRoleLabels(roles,page);
 buildTabs(roles,page);
 if(new URLSearchParams(location.search).get("accessDenied")==="1"){
  addNotice("You don't have access to that page.");
  const url=new URL(location.href);url.searchParams.delete("accessDenied");history.replaceState(null,"",url.pathname+url.search+url.hash);
 }
}
setup().catch(()=>{});
