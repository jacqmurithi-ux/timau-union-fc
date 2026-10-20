/* Anonymous PWA analytics. No IP, email, name, user agent, or location is collected. */
(() => {
 "use strict";
 const URL="https://owvvimydkjsjlrmnzvdi.supabase.co";
 const KEY="sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF";
 const dnt=navigator.doNotTrack==="1"||window.doNotTrack==="1"||navigator.globalPrivacyControl===true;
 if(dnt) return;
 const source=location.pathname.startsWith("/app/")?"app":"home", key="tufc_analytics_visitor_id";
 let visitor;
 try { visitor=localStorage.getItem(key); if(!visitor||!/^[0-9a-f-]{36}$/i.test(visitor)){visitor=crypto.randomUUID();localStorage.setItem(key,visitor);} } catch(_){return;}
 import("https://esm.sh/@supabase/supabase-js@2").then(({createClient})=>{
  const db=createClient(URL,KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
  const send=type=>db.rpc("record_event",{_event_type:type,_visitor_id:visitor,_source:source}).catch(()=>{});
  if(matchMedia("(display-mode: standalone)").matches||navigator.standalone===true){
   try{if(sessionStorage.getItem("tufc_app_open_sent")!=="1"){sessionStorage.setItem("tufc_app_open_sent","1");void send("app_open");}}catch(_){}
  }
  let deferred=null;
  addEventListener("beforeinstallprompt",e=>{deferred=e;void send("install_prompt_shown");});
  addEventListener("appinstalled",()=>{void send("install");deferred=null;});
  window.TimauPwaInstall={available:()=>Boolean(deferred),async prompt(){
   if(!deferred)return {outcome:"unavailable"};
   const event=deferred;deferred=null;
   try{await event.prompt();const choice=await event.userChoice;if(choice?.outcome==="accepted")void send("install_prompt_accepted");return {outcome:choice?.outcome||"unknown"};}
   catch(_){return {outcome:"error"};}
  }};
 }).catch(()=>{});
})();
