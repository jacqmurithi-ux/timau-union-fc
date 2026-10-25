(()=> {
 const cfg=window.TIMAU_SPONSORSHIP_CONFIG||{};
 const text=(selector,value)=>{const el=document.querySelector(selector);if(el&&typeof value==="string")el.textContent=value;};
 const run=async()=>{
  if(!cfg.supabaseUrl||!cfg.supabasePublishableKey)return;
  try{
   const response=await fetch(cfg.supabaseUrl+"/rest/v1/rpc/sponsor_page_content_get",{method:"POST",headers:{apikey:cfg.supabasePublishableKey,Authorization:"Bearer "+cfg.supabasePublishableKey,"Content-Type":"application/json"},body:"{}"});
   if(!response.ok)throw new Error("Page content unavailable");
   const c=await response.json();if(!c||!Array.isArray(c.packages))return;
   text(".partnership-hero .eyebrow",c.hero_eyebrow);text(".partnership-hero h1",c.hero_title);text(".partnership-hero .partnership-hero-inner>p:not(.eyebrow)",c.hero_description);
   text(".package-section>.eyebrow",c.section_eyebrow);text("#package-title",c.section_title);text(".package-intro",c.section_intro);
   text(".partnership-next-step h2",c.next_title);text(".partnership-next-step p",c.next_description);
   const grid=document.querySelector(".package-grid");if(grid){
    const existing=[...grid.querySelectorAll(".package-card")];
    c.packages.forEach((item,index)=>{
     let card=existing[index];if(!card)return;
     const heading=card.querySelector("h3"),description=card.querySelector(".package-description"),list=card.querySelector("ul");
     if(heading)heading.textContent=String(item.title||"");
     if(description)description.textContent=String(item.description||"");
     if(list){list.replaceChildren();String(item.benefits||"").split("\n").map(s=>s.trim()).filter(Boolean).forEach(line=>{const li=document.createElement("li");li.textContent=line;list.append(li);});}
     const link=card.querySelector("a");if(link){link.href="/register-interest.html?interest="+encodeURIComponent(String(item.key||"Other"));link.textContent="Enquire about this package";}
    });
   }
  }catch(error){console.warn("Sponsorship page content could not be refreshed.",error);}
 };
 if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",run,{once:true});else run();
})();