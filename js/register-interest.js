import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const cfg=window.TIMAU_SPONSORSHIP_CONFIG||{};
const db=createClient(cfg.supabaseUrl,cfg.supabasePublishableKey,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
const form=document.getElementById("sponsor-interest-form"),success=document.getElementById("form-success"),error=document.getElementById("form-error");
const started=Date.now();form.elements.form_started_ms.value=String(started);
const allowed=["Kit","Match day","Training","Website / social","Community partner","Other"];
const showError=m=>{error.textContent=m;error.hidden=false;success.hidden=true};
const initial=new URLSearchParams(location.search).get("interest");if(allowed.includes(initial))form.querySelectorAll('input[name="interests"]').forEach(x=>x.checked=x.value===initial);
form.addEventListener("submit",async e=>{e.preventDefault();error.hidden=true;success.hidden=true;const f=new FormData(form),name=String(f.get("name")||"").trim(),email=String(f.get("email")||"").trim(),business=String(f.get("business")||"").trim(),phone=String(f.get("phone")||"").trim(),message=String(f.get("message")||"").trim(),interests=f.getAll("interests");
if(name.length<2||name.length>120||!/^\S+@\S+\.\S+$/.test(email)||email.length>254||business.length<2||business.length>160||phone.length>40||message.length>2000||!interests.length||interests.some(x=>!allowed.includes(x))){showError("Please check your name, email, business and at least one interest.");return}
if(Date.now()-started<2500){showError("Please take a moment to review the form before submitting.");return}
const btn=form.querySelector('button[type="submit"]');btn.disabled=true;btn.textContent="Submitting…";
try{const result=await db.rpc("submit_sponsor_enquiry",{p_name:name,p_email:email,p_business:business,p_phone:phone||null,p_interests:interests,p_message:message||null,p_news_opt_in:f.get("news_opt_in")==="true",p_website_confirm:String(f.get("website_confirm")||""),p_form_started_ms:Number(f.get("form_started_ms"))});if(result.error)throw result.error;form.reset();form.elements.form_started_ms.value=String(Date.now());success.hidden=false;success.scrollIntoView({behavior:"smooth",block:"center"})}catch(err){showError("We couldn’t submit your interest right now. Please check the form and try again, or contact the club directly.")}finally{btn.disabled=false;btn.textContent="Register interest"}});
