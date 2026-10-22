import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient("https://owvvimydkjsjlrmnzvdi.supabase.co", "sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF", { auth: { persistSession: true, autoRefreshToken: true } });
const root = document.getElementById("homepage-hero");
if (root) {
  const track = root.querySelector("[data-hero-track]");
  const progress = root.querySelector("[data-hero-progress]");
  let slides = [];
  let index = 0;
  let timer = null;
  let paused = false;
  let startX = null;
  let hoverPaused = false;
  let focusPaused = false;
  let touchPaused = false;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const ROTATION_MS = 6000;

  const safeLink = value => {
    if (!value || Array.from(value).some(c => c.charCodeAt(0) === 92 || c.charCodeAt(0) < 32 || c.charCodeAt(0) === 127)) return "";
    try {
      const url = new URL(value, location.origin);
      if (!["http:", "https:"].includes(url.protocol)) return "";
      if (value.startsWith("/") && !value.startsWith("//") && url.origin === location.origin) return value;
      const lower = value.toLowerCase();
      return lower.startsWith("http://") || lower.startsWith("https://") ? url.href : "";
    } catch {
      return "";
    }
  };

  const ensureImage = async slideIndex => {
    const image = track.children[slideIndex]?.querySelector("img");
    if (!image || image.dataset.loaded === "true" || image.dataset.loaded === "loading") return;
    image.dataset.loaded = "loading";
    const { data, error } = await db.storage.from("homepage-hero").download(slides[slideIndex].image_path);
    if (error || !data) {
      image.dataset.loaded = "error";
      if (slideIndex === index) root.hidden = true;
      return;
    }
    const objectUrl = URL.createObjectURL(data);
    image.addEventListener("load", () => {
      image.dataset.loaded = "true";
    }, { once: true });
    image.addEventListener("error", () => {
      URL.revokeObjectURL(objectUrl);
      image.dataset.loaded = "error";
      if (slideIndex === index) root.hidden = true;
    }, { once: true });
    image.src = objectUrl;
  };

  const resetProgress = () => {
    [...progress.children].forEach((button, slideIndex) => {
      button.setAttribute("aria-current", String(slideIndex === index));
      const fill = button.querySelector("span");
      fill.style.transitionDuration = "0ms";
      fill.style.transform = "scaleX(0)";
    });
  };

  const animateProgress = () => {
    if (paused || reduceMotion || slides.length < 2) return;
    const fill = progress.children[index]?.querySelector("span");
    if (!fill) return;
    requestAnimationFrame(() => {
      if (paused || !fill.isConnected) return;
      fill.style.transitionDuration = ROTATION_MS + "ms";
      fill.style.transform = "scaleX(1)";
    });
  };

  const setActive = next => {
    if (!slides.length) return;
    index = (next + slides.length) % slides.length;
    [...track.children].forEach((slide, slideIndex) => {
      const active = slideIndex === index;
      slide.classList.toggle("is-active", active);
      slide.setAttribute("aria-hidden", String(!active));
    });
    resetProgress();
    ensureImage(index).catch(() => {
      if (index >= 0) root.hidden = true;
    });
    animateProgress();
  };

  const stop = () => {
    paused = true;
    clearInterval(timer);
    timer = null;
    [...progress.children].forEach(button => {
      const fill = button.querySelector("span");
      if (fill) fill.style.transitionDuration = "0ms";
    });
  };

  const start = () => {
    paused = false;
    clearInterval(timer);
    if (reduceMotion || slides.length < 2) return;
    setActive(index);
    timer = setInterval(() => setActive(index + 1), ROTATION_MS);
  };

  const resumeIfPossible = () => {
    if (!hoverPaused && !focusPaused && !touchPaused) start();
  };

  const showPrevious = () => setActive(index - 1);
  const showNext = () => setActive(index + 1);

  const createArrow = (direction, label, handler) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "hero-arrow hero-arrow-" + direction;
    button.setAttribute("aria-label", label);
    button.textContent = direction === "previous" ? "‹" : "›";
    button.addEventListener("click", () => {
      stop();
      handler();
      resumeIfPossible();
    });
    root.append(button);
    return button;
  };

  async function load() {
    const { data, error } = await db
      .from("homepage_hero_slides")
      .select("id,image_path,caption,link_url,alt_text,order_index,ends_at")
      .order("order_index")
      .limit(3);
    if (error || !data?.length) {
      root.hidden = true;
      return;
    }

    slides = data;
    for (let slideIndex = 0; slideIndex < data.length; slideIndex++) {
      const record = data[slideIndex];
      const slide = document.createElement("article");
      slide.className = "hero-slide";
      slide.setAttribute("aria-hidden", "true");

      const image = document.createElement("img");
      image.alt = record.alt_text;
      image.loading = slideIndex === 0 ? "eager" : "lazy";
      image.fetchPriority = slideIndex === 0 ? "high" : "auto";
      image.decoding = "async";
      image.dataset.loaded = "false";
      image.dataset.path = record.image_path;

      const caption = document.createElement("div");
      caption.className = "hero-slide-caption";
      const heading = document.createElement("h1");
      heading.textContent = record.caption;
      caption.append(heading);

      const href = safeLink(record.link_url);
      if (href) {
        const link = document.createElement("a");
        link.className = "hero-caption-link";
        link.href = href;
        link.textContent = "Read more";
        link.setAttribute("aria-label", "Read more: " + record.caption);
        caption.append(link);
      }

      slide.append(image, caption);
      track.append(slide);

      const segment = document.createElement("button");
      segment.type = "button";
      segment.className = "hero-progress-segment";
      segment.setAttribute("aria-label", "Show slide " + (slideIndex + 1));
      const fill = document.createElement("span");
      fill.setAttribute("aria-hidden", "true");
      segment.append(fill);
      segment.addEventListener("click", () => {
        stop();
        setActive(slideIndex);
        resumeIfPossible();
      });
      progress.append(segment);
    }

    if (slides.length > 1) {
      createArrow("previous", "Previous homepage highlight", showPrevious);
      createArrow("next", "Next homepage highlight", showNext);
    }

    root.hidden = false;
    setActive(0);
    start();
  }

  root.addEventListener("mouseenter", () => {
    hoverPaused = true;
    stop();
  });
  root.addEventListener("mouseleave", () => {
    hoverPaused = false;
    resumeIfPossible();
  });
  root.addEventListener("focusin", () => {
    focusPaused = true;
    stop();
  });
  root.addEventListener("focusout", event => {
    if (!root.contains(event.relatedTarget)) {
      focusPaused = false;
      resumeIfPossible();
    }
  });
  root.addEventListener("touchstart", event => {
    touchPaused = true;
    stop();
    startX = event.changedTouches[0].clientX;
  }, { passive: true });
  root.addEventListener("touchend", event => {
    if (startX !== null) {
      const delta = event.changedTouches[0].clientX - startX;
      if (Math.abs(delta) > 45 && slides.length > 1) {
        setActive(index + (delta < 0 ? 1 : -1));
      }
    }
    startX = null;
    touchPaused = false;
    resumeIfPossible();
  }, { passive: true });
  root.addEventListener("keydown", event => {
    if (event.target.closest("a,button,input,textarea,select")) return;
    if (event.key === "ArrowLeft" && slides.length > 1) {
      event.preventDefault();
      stop();
      showPrevious();
      resumeIfPossible();
    } else if (event.key === "ArrowRight" && slides.length > 1) {
      event.preventDefault();
      stop();
      showNext();
      resumeIfPossible();
    }
  });

  load().catch(() => {
    root.hidden = true;
  });
}
