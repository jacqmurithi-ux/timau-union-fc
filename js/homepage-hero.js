import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient("https://owvvimydkjsjlrmnzvdi.supabase.co", "sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF", { auth: { persistSession: true, autoRefreshToken: true } });
const root = document.getElementById("homepage-hero");
if (!root) { /* Hero is intentionally absent when there are no published slides. */ }
else {
  const track = root.querySelector("[data-hero-track]");
  const progress = root.querySelector("[data-hero-progress]");
  let slides = [], index = 0, timer = null, paused = false, startX = null, hoverPaused = false, focusPaused = false, touchPaused = false;
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const safeLink = value => {
    if (!value || value.includes("\\\\") || /[\\u0000-\\u001f\\u007f]/.test(value)) return "";
    try {
      const u = new URL(value, location.origin);
      if (!["http:", "https:"].includes(u.protocol)) return "";
      if (value.startsWith("/") && !value.startsWith("//") && u.origin === location.origin) return value;
      return /^https?:\\/\\//i.test(value) ? u.href : "";
    } catch { return ""; }
  };
  const ensureImage = async i => {
    const image = track.children[i]?.querySelector("img");
    if (!image || image.dataset.loaded === "true" || image.dataset.loaded === "loading") return;
    image.dataset.loaded = "loading";
    const { data, error } = await db.storage.from("homepage-hero").download(slides[i].image_path);
    if (error || !data) { image.dataset.loaded = "error"; root.hidden = true; return; }
    image.src = URL.createObjectURL(data);
    image.dataset.loaded = "true";
  };
  const setActive = next => {
    if (!slides.length) return;
    index = (next + slides.length) % slides.length;
    [...track.children].forEach((el, i) => el.hidden = i !== index);
    [...progress.children].forEach((el, i) => {
      el.setAttribute("aria-current", String(i === index));
      const fill = el.querySelector("span");
      fill.style.transitionDuration = "0ms";
      fill.style.transform = "scaleX(0)";
    });
    ensureImage(index).catch(() => {});
    const activeFill = progress.children[index]?.querySelector("span");
    if (activeFill && !paused && !reduceMotion) {
      requestAnimationFrame(() => {
        if (paused) return;
        activeFill.style.transitionDuration = "6000ms";
        activeFill.style.transform = "scaleX(1)";
      });
    }
  };
  const stop = () => { paused = true; clearInterval(timer); timer = null; [...progress.children].forEach(el => el.querySelector("span").style.transitionDuration = "0ms"); };
  const start = () => {
    paused = false; clearInterval(timer);
    if (reduceMotion || slides.length < 2) return;
    setActive(index);
    timer = setInterval(() => setActive(index + 1), 6000);
  };
  async function load() {
    const { data, error } = await db.from("homepage_hero_slides").select("id,image_path,caption,link_url,alt_text,order_index,ends_at").order("order_index").limit(3);
    if (error || !data?.length) { root.hidden = true; return; }
    slides = data;
    for (let i=0; i<data.length; i++) {
      const s=data[i], slide=document.createElement("article");
      slide.className="hero-slide"; slide.hidden=true;
      const image=document.createElement("img"); image.alt=s.alt_text; image.loading=i===0?"eager":"lazy"; image.fetchPriority=i===0?"high":"auto";
      image.dataset.loaded = "false";
      image.dataset.path = s.image_path;
      const caption=document.createElement("div"); caption.className="hero-slide-caption";
      const h=document.createElement("h1"); h.textContent=s.caption; caption.append(h);
      if (s.link_url) { const href=safeLink(s.link_url); if(href){const a=document.createElement("a");a.className="hero-caption-link";a.href=href;a.textContent="Read more";a.setAttribute("aria-label","Read more: "+s.caption);caption.append(a);slide.classList.add("hero-slide-linked");slide.addEventListener("click",e=>{if(e.target.closest("a"))return;location.href=href;});slide.tabIndex=0;slide.setAttribute("role","link");slide.addEventListener("keydown",e=>{if(e.target===slide&&(e.key==="Enter"||e.key===" ")){e.preventDefault();location.href=href;}});}}
      slide.append(image,caption); track.append(slide);
      const button=document.createElement("button");button.type="button";button.className="hero-progress-segment";button.setAttribute("aria-label","Show slide "+(i+1));const fill=document.createElement("span");button.append(fill);button.addEventListener("click",()=>{stop();setActive(i);resumeIfPossible();});progress.append(button);
    }
    root.hidden=false;setActive(0);start();
  }
  const resumeIfPossible = () => { if (!hoverPaused && !focusPaused && !touchPaused) start(); };
  root.addEventListener("mouseenter",()=>{hoverPaused=true;stop();});
  root.addEventListener("mouseleave",()=>{hoverPaused=false;resumeIfPossible();});
  root.addEventListener("focusin",()=>{focusPaused=true;stop();});
  root.addEventListener("focusout",e=>{if(!root.contains(e.relatedTarget)){focusPaused=false;resumeIfPossible();}});
  root.addEventListener("touchstart",e=>{touchPaused=true;stop();startX=e.changedTouches[0].clientX;},{passive:true});
  root.addEventListener("touchend",e=>{if(startX!==null){const delta=e.changedTouches[0].clientX-startX;if(Math.abs(delta)>45)setActive(index+(delta<0?1:-1));}startX=null;touchPaused=false;resumeIfPossible();},{passive:true});
  load().catch(()=>{root.hidden=true;});
}
