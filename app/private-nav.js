import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const db=createClient("https://owvvimydkjsjlrmnzvdi.supabase.co","sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF",{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=s=>document.querySelector(s);
const add=(root,label,href)=>{const a=document.createElement("a");a.className="text-link";a.textContent=label;a.href=href;root.append(a)};
async function setup(){
 const root=$(".site-header .access-actions");if(!root)return;
 const signout=$("#signout");root.querySelectorAll("a").forEach(a=>a.remove());
 const {data:{session}}=await db.auth.getSession();if(!session)return;
 const {data,error}=await db.rpc("club_get_workspace_bundle");if(error)return;
 const roles=Array.isArray(data?.roles)?data.roles:[],admin=Boolean(data?.is_platform_admin)||roles.includes("chairman"),has=(...r)=>admin||r.some(x=>roles.includes(x));
 const sections=[
  ["Players","player",has("team_manager","secretary")],
  ["Fixtures & results","fixture",has("team_manager","secretary","coach")],
  ["News","news",has("media_team","secretary")],
  ["Sponsors","sponsor",has("sponsor_lead","secretary")],
  ["Activities","activity",has("team_manager","secretary","coach")]
 ];
 for(const [label,type,allowed] of sections)if(allowed)add(root,label,"./workspace.html?type="+encodeURIComponent(type));
 if(has("coach"))add(root,"Coach dashboard","./coach.html");
 if(has("secretary"))add(root,"Secretary workspace","./secretary.html");
 if(has("treasurer"))add(root,"Finance / requisitions","./treasurer.html");
 if(has("sponsor_lead"))add(root,"Sponsor Lead","./sponsor-lead.html");
 if(has("media_team"))add(root,"Media Team","./media.html");
 if(has("team_manager","coach","assistant_coach","secretary"))add(root,"Kit & equipment","./kit.html");
 if(has("team_manager","secretary","chairman","vice_chairman","treasurer","coach","media_team","sponsor_lead","player_welfare"))add(root,"Home attendance","./home-attendance.html");
 if(signout)root.append(signout);
}
setup().catch(()=>{});
