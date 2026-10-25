import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const cfg=window.TIMAU_SPONSORSHIP_CONFIG||{};
const form=document.getElementById("sponsor-interest-form");
const success=document.getElementById("form-success");
const error=document.getElementById("form-error");
if(!form||!success||!error) throw new Error("Partnership enquiry form is unavailable.");
const db=createClient(cfg.supabaseUrl,cfg.supabasePublishableKey,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
const started=Date.now();
form.elements.form_started_ms.value=String(started);
const allowed=["Kit","Match day","Training","Website / social","Community partner","Other"];
const showError=message=>{error.textContent=message;error.hidden=false;success.hidden=true;};
const interestSelect=form.elements.interest;
const initial=new URLSearchParams(location.search).get("interest");
if(allowed.includes(initial)) interestSelect.value=initial;
form.addEventListener("submit",async event=>{
  event.preventDefault();error.hidden=true;success.hidden=true;
  const values=new FormData(form);
  const name=String(values.get("name")||"").trim();
  const email=String(values.get("email")||"").trim();
  const business=String(values.get("business")||"").trim();
  const phone=String(values.get("phone")||"").trim();
  const message=String(values.get("message")||"").trim();
  const interest=String(values.get("interest")||"");
  if(name.length<2||name.length>120||!/^\\S+@\\S+\\.\\S+$/.test(email)||email.length>254||business.length<2||business.length>160||phone.length>40||message.length>2000||!allowed.includes(interest)){
    showError("Please check your name, business or organisation, email address and package of interest.");return;
  }
  if(values.get("website_confirm")) { showError("We couldn’t submit your enquiry. Please try again.");return; }
  if(Date.now()-started<1800){showError("Please take a moment to review your enquiry before submitting.");return;}
  const button=form.querySelector('button[type="submit"]');
  button.disabled=true;button.textContent="Sending enquiry…";
  try{
    const result=await db.rpc("submit_sponsor_enquiry",{
      p_name:name,p_email:email,p_business:business,p_phone:phone||null,
      p_interests:[interest],p_message:message||null,
      p_news_opt_in:values.get("news_opt_in")==="true",
      p_website_confirm:"",p_form_started_ms:Number(form.elements.form_started_ms.value)
    });
    if(result.error) throw result.error;
    form.reset();form.elements.form_started_ms.value=String(Date.now());
    success.hidden=false;success.scrollIntoView({behavior:"smooth",block:"center"});
  }catch(_err){
    showError("We couldn’t send your enquiry right now. Please try again, or contact the club directly.");
  }finally{button.disabled=false;button.textContent="Send partnership enquiry";}
});
