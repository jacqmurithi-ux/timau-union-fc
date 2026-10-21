import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient("https://owvvimydkjsjlrmnzvdi.supabase.co", "sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF", { auth: { persistSession: true, autoRefreshToken: true } });
const root = document.getElementById("homepage-hero");
if (!root) { /* Hero is intentionally absent when there are no published slides. */ }
else {
  const track = root.querySelector("[data-hero-track]");
  const progress = root.querySelector("[data-hero-progress]");
  let slides = [], index = 0, timer = null, paused = false, startX = null;
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const safeLink = value => {
    if (!value) return "";
    if (value.startsWith("/") && !value.startsWith("//")) return value;
    try { const u = new URL(value); return ["http:", "https:"].includes(u.protocol) ? u.href : ""; } catch { return ""; }
  };
  const setActive = next => {
    if (!slides.length) return;
    index = (next + slides.length) % slides.length;
    [...track.children].forEach((el, i) => el.hidden = i !== index);
    [...progress.children].forEach((el, i) => {
      el.setAttribute("aria-current", String(i === index));
      const fill = el.querySelector("span");
      fill.style.transform = i === index ? "scaleX(1)" : "scaleX(0)";
      fill.style.transitionDuration = (!paused && !reduceMotion && i === index) ? "6000ms" : "0ms";
    });
  };
  const stop = () => { paused = true; clearInterval(timer); timer = null; [...progress.children].forEach(el => el.querySelector("span").style.transitionDuration = "0ms"); };
  const start = () => {
    paused = false; clearInterval(timer);
    if (reduceMotion || slides.length < 2) return;
    setActive(index);
    timer = setInterval(() => setActive(index + 1), 6000);
  };
  async function load() {
    const { data, error } = await db.from("homepage_hero_slides").select("id,image_path,caption,link_url,alt_text,order_index,ends_at").or("ends_at.is.null,ends_at.gt." + new Date().toISOString()).order("order_index").limit(3);
    if (error || !data?.length) { root.hidden = true; return; }
    slides = data;
    for (let i=0; i<data.length; i++) {
      const s=data[i], slide=document.createElement("article");
      slide.className="hero-slide"; slide.hidden=true;
      const image=document.createElement("img"); image.alt=s.alt_text; image.loading=i===0?"eager":"lazy"; image.fetchPriority=i===0?"high":"auto";
      const {data:imageBlob,error:imageError}=await db.storage.from("homepage-hero").download(s.image_path); if(imageError||!imageBlob){root.hidden=true;return;} image.src=URL.createObjectURL(imageBlob);
      const caption=document.createElement("div"); caption.className="hero-slide-caption";
      const h=document.createElement("h1"); h.textContent=s.caption; caption.append(h);
      if (s.link_url) { const href=safeLink(s.link_url); if(href){const a=document.createElement("a");a.className="hero-caption-link";a.href=href;a.textContent="Read more";a.setAttribute("aria-label","Read more: "+s.caption);caption.append(a);slide.classList.add("hero-slide-linked");slide.addEventListener("click",e=>{if(e.target.closest("a"))return;location.href=href;});slide.tabIndex=0;slide.setAttribute("role","link");slide.addEventListener("keydown",e=>{if(e.target===slide&&(e.key==="Enter"||e.key===" ")){e.preventDefault();location.href=href;}});}}
      slide.append(image,caption); track.append(slide);
      const button=document.createElement("button");button.type="button";button.className="hero-progress-segment";button.setAttribute("aria-label","Show slide "+(i+1));const fill=document.createElement("span");button.append(fill);button.addEventListener("click",()=>{stop();setActive(i);start();});progress.append(button);
    }
    root.hidden=false;setActive(0);start();
  }
  root.addEventListener("mouseenter",stop); root.addEventListener("mouseleave",start);
  root.addEventListener("focusin",stop); root.addEventListener("focusout",start);
  root.addEventListener("touchstart",e=>{stop();startX=e.changedTouches[0].clientX;},{passive:true});
  root.addEventListener("touchend",e=>{if(startX===null)return;const delta=e.changedTouches[0].clientX-startX;if(Math.abs(delta)>45)setActive(index+(delta<0?1:-1));startX=null;start();},{passive:true});
  load().catch(()=>{root.hidden=true;});
}
