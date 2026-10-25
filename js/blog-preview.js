import {createClient} from "https://esm.sh/@supabase/supabase-js@2";

const BLOG_URL = "https://blog.timauunionfc.co.ke/";
const db = createClient(
  "https://owvvimydkjsjlrmnzvdi.supabase.co",
  "sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF"
);
const root = document.getElementById("blog-preview-list");

function node(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}
function safeImageUrl(value) {
  try {
    const url = new URL(value);
    return ["https:", "http:"].includes(url.protocol) ? url.href : "";
  } catch {
    return "";
  }
}
function categoryName(value) {
  return ({
    "match-reports": "Match report",
    "club-news": "Club news",
    community: "Community story"
  })[value] || "Club story";
}
function storyUrl(slug) {
  return BLOG_URL + "story.html?slug=" + encodeURIComponent(slug);
}
function showFallback(message) {
  root.replaceChildren();
  const status = node("p", "blog-preview-status", message + " ");
  const link = node("a", "", "Visit the public blog →");
  link.href = BLOG_URL;
  link.target = "_blank";
  link.rel = "noopener noreferrer";
  status.append(link);
  root.append(status);
}

async function renderBlogPreview() {
  if (!root) return;
  try {
    const { data, error } = await db
      .from("blog_articles")
      .select("slug,title,excerpt,category,image_url,published_at")
      .eq("status", "published")
      .order("published_at", { ascending: false })
      .limit(3);
    if (error) throw error;
    if (!Array.isArray(data) || data.length === 0) {
      showFallback("No published stories are available right now.");
      return;
    }
    root.replaceChildren();
    for (const article of data) {
      const url = storyUrl(article.slug);
      const card = node("article", "blog-preview-card");
      const imageLink = node("a", "blog-preview-image-link");
      imageLink.href = url;
      imageLink.target = "_blank";
      imageLink.rel = "noopener noreferrer";
      imageLink.setAttribute("aria-label", "Read " + article.title);
      const imageUrl = safeImageUrl(article.image_url);
      if (imageUrl) {
        const image = node("img");
        image.src = imageUrl;
        image.alt = "";
        image.loading = "lazy";
        image.decoding = "async";
        imageLink.append(image);
      } else {
        imageLink.append(node("span", "blog-preview-image-fallback", "TIMAU UNION FC"));
      }
      card.append(imageLink);
      const body = node("div", "blog-preview-body");
      const meta = node("p", "blog-preview-meta");
      meta.append(node("span", "", categoryName(article.category)));
      if (article.published_at) {
        const date = new Date(article.published_at);
        if (!Number.isNaN(date.getTime())) {
          meta.append(node("span", "", "·"));
          meta.append(node("time", "", new Intl.DateTimeFormat("en-KE", {
            day: "numeric", month: "short", year: "numeric"
          }).format(date)));
        }
      }
      const heading = node("h3");
      const headingLink = node("a", "", article.title || "Read the latest story");
      headingLink.href = url;
      headingLink.target = "_blank";
      headingLink.rel = "noopener noreferrer";
      heading.append(headingLink);
      body.append(meta, heading);
      if (article.excerpt) body.append(node("p", "blog-preview-excerpt", article.excerpt));
      const read = node("a", "blog-preview-read", "Read story →");
      read.href = url;
      read.target = "_blank";
      read.rel = "noopener noreferrer";
      body.append(read);
      card.append(body);
      root.append(card);
    }
  } catch {
    showFallback("The latest stories could not be loaded right now.");
  }
}
renderBlogPreview();
