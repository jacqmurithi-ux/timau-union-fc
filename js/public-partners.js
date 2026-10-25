(()=> {
  const config=window.TIMAU_SPONSORSHIP_CONFIG||{};
  const escapeHtml=value=>String(value??"").replace(/[&<>"']/g,char=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[char]));
  const safeUrl=value=>{try{const url=new URL(value);return ["http:","https:"].includes(url.protocol)?url.href:"";}catch{return "";}};
  const initials=value=>String(value||"TUFC").trim().split(/\s+/).slice(0,2).map(part=>part[0]||"").join("").toUpperCase()||"TUFC";
  document.addEventListener("DOMContentLoaded",async()=>{
    const targets=[...document.querySelectorAll("[data-public-partners]")];
    if(!targets.length)return;
    const setVisibility=(target,visible)=>{
      const section=target.closest("[data-approved-partners-section]");
      if(section)section.hidden=!visible;
      const heading=target.parentElement?.querySelector(".approved-partners-heading")||target.closest("#sponsors")?.querySelector(".approved-partners-heading");
      if(heading)heading.hidden=!visible;
      if(target.closest("#sponsors"))target.hidden=!visible;
    };
    const empty='<p class="partner-empty-state">No approved partners have been announced yet.</p>';
    const unavailable='<p class="partner-empty-state">Approved partner information is temporarily unavailable.</p>';
    targets.forEach(target=>{setVisibility(target,false);target.innerHTML="";});
    if(!config.supabaseUrl||!config.supabasePublishableKey){targets.forEach(target=>{target.innerHTML=unavailable;setVisibility(target,false);});return;}
    try{
      const response=await fetch(config.supabaseUrl+"/rest/v1/public_partners?select=name,support_type,public_description,website,fan_offer_text&order=name.asc",{
        headers:{apikey:config.supabasePublishableKey,Authorization:"Bearer "+config.supabasePublishableKey}
      });
      if(!response.ok)throw new Error("Public partner request failed");
      const rows=await response.json();
      targets.forEach(target=>{
        const list=target.dataset.offers==="true"?rows.filter(row=>row.fan_offer_text):rows;
        if(!list.length){target.innerHTML=empty;setVisibility(target,false);return;}
        target.innerHTML=list.map(row=>{
          const website=safeUrl(row.website);
          const logo=website
            ?'<img class="partner-logo" src="https://www.google.com/s2/favicons?domain_url='+encodeURIComponent(website)+'&sz=128" alt="" loading="lazy" width="64" height="64">'
            :'<span class="partner-logo-fallback" aria-hidden="true">'+escapeHtml(initials(row.name))+'</span>';
          return '<article class="partner-card approved-partner-card"><div class="partner-logo-wrap">'+logo+'</div><h3>'+escapeHtml(row.name)+'</h3>'+
            (row.support_type?'<p class="partner-support-type">'+escapeHtml(row.support_type)+'</p>':'')+
            (row.public_description?'<p>'+escapeHtml(row.public_description)+'</p>':'')+
            (target.dataset.offers==="true"&&row.fan_offer_text?'<p>'+escapeHtml(row.fan_offer_text)+'</p>':'')+
            (website?'<a class="text-link" href="'+escapeHtml(website)+'" target="_blank" rel="noopener noreferrer">Visit partner →</a>':'')+'</article>';
        }).join("");
        target.querySelectorAll(".partner-logo").forEach(img=>img.addEventListener("error",()=>{
          const fallback=document.createElement("span");fallback.className="partner-logo-fallback";fallback.setAttribute("aria-hidden","true");
          fallback.textContent=initials(img.closest(".partner-card")?.querySelector("h3")?.textContent);
          img.replaceWith(fallback);
        },{once:true}));
        setVisibility(target,true);
      });
    }catch{
      targets.forEach(target=>{target.innerHTML=unavailable;setVisibility(target,false);});
    }
  });
})();