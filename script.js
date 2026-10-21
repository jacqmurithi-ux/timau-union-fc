"use strict";

function initializePage() {
  const menuToggle = document.getElementById("menu-toggle");
  const primaryNav = document.getElementById("primary-nav");

  if (menuToggle && primaryNav) {
    const menuLabel = menuToggle.querySelector(".menu-label");
    const menuIcon = menuToggle.querySelector(".menu-icon");

    const setMenuState = (isOpen, returnFocus = false) => {
      primaryNav.classList.toggle("is-open", isOpen);
      menuToggle.setAttribute("aria-expanded", String(isOpen));
      if (menuLabel) menuLabel.textContent = isOpen ? "Close" : "Menu";
      if (menuIcon) {
        menuIcon.textContent = isOpen ? "×" : "☰";
        menuIcon.setAttribute("aria-hidden", "true");
      }
      if (returnFocus) menuToggle.focus();
    };

    menuToggle.addEventListener("click", () => {
      setMenuState(menuToggle.getAttribute("aria-expanded") !== "true");
    });
    primaryNav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => setMenuState(false));
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && primaryNav.classList.contains("is-open")) {
        setMenuState(false, true);
      }
    });
    const desktopLayout = window.matchMedia("(min-width: 900px)");
    const handleLayoutChange = (event) => {
      if (event.matches) setMenuState(false);
    };
    if (desktopLayout.addEventListener) {
      desktopLayout.addEventListener("change", handleLayoutChange);
    } else {
      desktopLayout.addListener(handleLayoutChange);
    }
  }

  const yearElement = document.getElementById("current-year");
  if (yearElement) yearElement.textContent = String(new Date().getFullYear());

  loadFeaturedNews();
  loadMatchCentre();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initializePage, { once: true });
} else {
  initializePage();
}

async function loadMatchCentre() {
  const section = document.getElementById("fixtures");
  const feature = section && section.querySelector(".match-feature");
  const statusLabel = section && section.querySelector(".status-label");
  const notice = section && section.querySelector(".notice");
  if (!section || !feature || !statusLabel || !notice) return;

  try {
    const response = await fetch("data/matches.json", { cache: "no-store" });
    if (!response.ok) throw new Error("Match data unavailable");
    const matches = await response.json();
    if (!Array.isArray(matches) || matches.length === 0) return;

    const latest = matches[0];
    if (!isUsableMatch(latest)) return;

    const stylesheet = document.createElement("link");
    stylesheet.rel = "stylesheet";
    stylesheet.href = "css/match-centre.css";
    document.head.appendChild(stylesheet);

    clearChildren(feature);
    feature.classList.add("match-feature-live");
    feature.appendChild(createFeatureHeading());
    const body = makeElement("div", "match-feature-body match-latest-body");
    body.appendChild(makeElement("p", "match-status", "OFFICIAL CLUB UPDATES"));
    body.appendChild(makeElement("p", "match-competition", latest.competition));
    body.appendChild(makeElement("p", "match-stage", latest.stage));
    body.appendChild(makeElement("h3", "matchup", latest.home + " vs " + latest.away));

    const result = makeElement("span", "result-pill result-" + latest.result.toLowerCase(),
      resultLabel(latest.result));
    result.setAttribute("aria-label", "Result: " + resultLabel(latest.result));
    body.appendChild(result);

    if (latest.score !== null && latest.score !== undefined && String(latest.score).trim() !== "") {
      body.appendChild(makeElement("p", "match-score", String(latest.score)));
    }

    body.appendChild(makeElement("p", "match-date", formatMatchDate(latest.date)));
    body.appendChild(makeElement("p", "match-venue", latest.venue));
    if (latest.result === "L" && typeof latest.stage === "string" &&
        latest.stage.toLowerCase().includes("final")) {
      body.appendChild(makeElement("p", "match-respect-line",
        "Season ended in the playoff quarter-finals. Thank you for the support."));
    }
    feature.appendChild(body);

    const footer = makeElement("div", "match-feature-footer");
    footer.appendChild(makeElement("span", "", "Timau Union FC"));
    footer.appendChild(makeElement("span", "", "Meru County, Kenya"));
    feature.appendChild(footer);

    statusLabel.textContent = "Latest result";
    notice.hidden = true;

    const oldList = section.querySelector(".previous-results");
    if (oldList) oldList.remove();
    if (matches.length > 1) {
      const previous = makeElement("section", "previous-results");
      previous.setAttribute("aria-labelledby", "previous-results-title");
      previous.appendChild(makeElement("h3", "previous-results-title", "Previous results"));
      const list = makeElement("ul", "previous-results-list");
      matches.slice(1).forEach((match) => {
        if (!isUsableMatch(match)) return;
        const item = makeElement("li", "previous-result-row");
        const details = makeElement("div", "previous-result-details");
        details.appendChild(makeElement("strong", "", match.home + " vs " + match.away));
        details.appendChild(makeElement("span", "", match.competition + " · " + match.stage));
        details.appendChild(makeElement("span", "", formatMatchDate(match.date) + " · " + match.venue));
        item.appendChild(details);
        const summary = match.score !== null && match.score !== undefined && String(match.score).trim() !== ""
          ? String(match.score)
          : resultLabel(match.result);
        item.appendChild(makeElement("span", "result-pill result-" + match.result.toLowerCase(), summary));
        list.appendChild(item);
      });
      if (list.children.length > 0) {
        previous.appendChild(list);
        feature.insertAdjacentElement("afterend", previous);
      }
    }
  } catch (_error) {
    // Keep the original "Updates pending confirmation" state if data cannot load.
  }
}

function isUsableMatch(match) {
  return Boolean(match && typeof match.competition === "string" &&
    typeof match.stage === "string" && typeof match.date === "string" &&
    typeof match.home === "string" && typeof match.away === "string" &&
    typeof match.venue === "string" && ["W", "D", "L"].includes(match.result));
}

function makeElement(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}

function clearChildren(element) {
  while (element.firstChild) element.removeChild(element.firstChild);
}

function createFeatureHeading() {
  const heading = makeElement("div", "match-feature-heading");
  heading.appendChild(makeElement("span", "match-label", "FIXTURES & RESULTS"));
  const ball = makeElement("span", "match-ball", "⚽");
  ball.setAttribute("aria-hidden", "true");
  heading.appendChild(ball);
  return heading;
}

function resultLabel(result) {
  return ({ W: "Win", D: "Draw", L: "Defeat" })[result] || "Result";
}

function formatMatchDate(value) {
  const date = new Date(value + "T00:00:00Z");
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric", month: "long", year: "numeric", timeZone: "UTC"
  }).format(date);
}


async function loadFeaturedNews() {
  const section = document.getElementById("featured-news");
  const list = document.getElementById("featured-news-list");
  if (!section || !list) return;

  try {
    const response = await fetch("data/news.json", { cache: "no-store" });
    if (!response.ok) return;
    const records = await response.json();
    if (!Array.isArray(records)) return;

    const featured = records
      .filter((item) => item && item.featured === true &&
        typeof item.title === "string" && item.title.trim() &&
        typeof item.date === "string" && /^\\d{4}-\\d{2}-\\d{2}$/.test(item.date) &&
        isSafeNewsLink(item.link))
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, 4);

    if (featured.length === 0) return;

    featured.forEach((item) => {
      const row = document.createElement("li");
      row.className = "featured-news-item";
      const link = document.createElement("a");
      link.className = "featured-news-link";
      link.href = item.link;

      const altText = typeof item.alt === "string" && item.alt.trim()
        ? item.alt.trim()
        : "Timau Union FC club crest";
      const image = document.createElement("img");
      image.className = "featured-news-thumb";
      image.width = 64;
      image.height = 64;
      image.loading = "lazy";
      image.alt = altText;
      image.src = isSafeNewsImage(item.image) ? item.image : "assets/club-crest.jpg";
      image.addEventListener("error", () => {
        if (image.dataset.fallbackTried === "true") {
          const fallback = document.createElement("span");
          fallback.className = "featured-news-fallback";
          fallback.setAttribute("aria-hidden", "true");
          fallback.textContent = "⚽";
          image.replaceWith(fallback);
          return;
        }
        image.dataset.fallbackTried = "true";
        image.src = "assets/club-crest.jpg";
      }, { once: false });
      link.appendChild(image);

      const copy = document.createElement("span");
      copy.className = "featured-news-copy";
      const headline = document.createElement("span");
      headline.className = "featured-news-headline";
      headline.textContent = item.title;
      copy.appendChild(headline);

      const date = document.createElement("span");
      date.className = "featured-news-date";
      date.textContent = formatMatchDate(item.date);
      copy.appendChild(date);
      link.appendChild(copy);
      row.appendChild(link);
      list.appendChild(row);
    });

    section.hidden = false;
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      section.classList.add("is-visible");
    }
  } catch (_error) {
    // Keep the whole block hidden when the data file cannot be loaded.
  }
}

function isSafeNewsLink(value) {
  if (typeof value !== "string" || !value.trim()) return false;
  const link = value.trim();
  if (link.startsWith("#")) return !/^#\\s*$/.test(link);
  if (link.startsWith("/") && !link.startsWith("//")) return true;
  if (link.startsWith("./") || link.startsWith("../")) return true;
  try {
    const parsed = new URL(link, window.location.href);
    return parsed.protocol === "https:" && parsed.origin !== "null";
  } catch (_error) {
    return false;
  }
}

function isSafeNewsImage(value) {
  if (typeof value !== "string" || !value.trim()) return false;
  const image = value.trim();
  return !image.startsWith("//") && !/^[a-z][a-z0-9+.-]*:/i.test(image) &&
    !image.startsWith("/") && !image.split("/").includes("..");
}
