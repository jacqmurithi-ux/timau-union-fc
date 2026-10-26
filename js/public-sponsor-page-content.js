(()=> {
 const cfg=window.TIMAU_SPONSORSHIP_CONFIG||{};
 const text=(selector,value)=>{const el=document.querySelector(selector);if(el&&typeof value==="string")el.textContent=value;};
 const node=(tag,className,content)=>{const el=document.createElement(tag);if(className)el.className=className;if(content!==undefined)el.textContent=String(content);return el;};
 const renderPackages=(grid,packages)=>{
  grid.replaceChildren();
  if(!packages.length){grid.append(node("p","partner-empty-state","Partnership packages are being updated. Please contact the club to discuss ways to support the team."));return;}
  packages.forEach(item=>{
   const key=String(item.key||"Other"),title=String(item.title||key),description=String(item.description||"");
   const card=node("article","partner-card package-card");
   if(item.image_url){const img=node("img","package-mockup-image");img.loading="lazy";img.decoding="async";img.src=String(item.image_url);img.alt=title+" sponsorship visual";img.style.cssText="display:block;width:100%;max-height:220px;object-fit:contain;background:#f5f5f5;border-radius:8px;margin:0 0 1rem";card.append(img);}
   card.append(node("h3","",title),node("p","package-description",description));
   const benefits=node("ul","");
   String(item.benefits||"").split("\n").map(line=>line.trim()).filter(Boolean).forEach(line=>benefits.append(node("li","",line)));
   if(benefits.children.length)card.append(benefits);
   const link=node("a","button button-primary","Enquire about this package");
   link.href="/register-interest.html?interest="+encodeURIComponent(key);
   card.append(link);grid.append(card);
  });
 };
 const run=async()=>{
  if(!cfg.supabaseUrl||!cfg.supabasePublishableKey)return;
  try{
   const response=await fetch(cfg.supabaseUrl+"/rest/v1/rpc/sponsor_page_content_get",{method:"POST",headers:{apikey:cfg.supabasePublishableKey,Authorization:"Bearer "+cfg.supabasePublishableKey,"Content-Type":"application/json"},body:"{}"});
   if(!response.ok)throw new Error("Page content unavailable");
   const c=await response.json();if(!c||!Array.isArray(c.packages))return;
   text(".partnership-hero .eyebrow",c.hero_eyebrow);text(".partnership-hero h1",c.hero_title);text(".partnership-hero .partnership-hero-inner>p:not(.eyebrow)",c.hero_description);
   text(".package-section>.eyebrow",c.section_eyebrow);text("#package-title",c.section_title);text(".package-intro",c.section_intro);
   text(".partnership-next-step h2",c.next_title);text(".partnership-next-step p",c.next_description);
   const grid=document.querySelector(".package-grid");if(grid)renderPackages(grid,c.packages);
  }catch(error){console.warn("Sponsorship page content could not be refreshed; keeping the built-in public fallback.",error);}
 };
 if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",run,{once:true});else run();
})();