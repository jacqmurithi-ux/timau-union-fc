import { getPublishedClubContent } from "./js/published-content.js";

"use strict";

function initializePage() {
  // Shared public navigation is initialized by js/site-header.js on each public page.

  const searchToggle = document.getElementById("site-search-toggle");
  const searchPanel = document.getElementById("site-search-panel");
  const searchForm = document.getElementById("site-search-form");
  const searchInput = document.getElementById("site-search-input");
  const searchResults = document.getElementById("site-search-results");
  if (searchToggle && searchPanel && searchForm && searchInput && searchResults) {
    const openSearch = (open) => {
      searchPanel.hidden = !open;
      searchPanel.classList.toggle("is-open", open);
      searchToggle.setAttribute("aria-expanded", String(open));
      if (open) searchInput.focus();
    };
    searchToggle.addEventListener("click", () => openSearch(searchPanel.hidden));
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && !searchPanel.hidden) { openSearch(false); searchToggle.focus(); }
    });
    searchForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const query = searchInput.value.trim().toLocaleLowerCase();
      searchResults.replaceChildren();
      if (query.length < 2) {
        searchResults.appendChild(makeElement("p", "", "Enter at least two characters."));
        return;
      }
      const matches = [];
      document.querySelectorAll("main h1, main h2, main h3, main .match-feature, main .news-card, main article").forEach((node) => {
        if (!node.textContent.toLocaleLowerCase().includes(query)) return;
        const heading = node.matches("h1,h2,h3") ? node : node.querySelector("h1,h2,h3");
        const label = (heading ? heading.textContent : node.textContent).trim().replace(/\s+/g, " ").slice(0, 150);
        if (!label) return;
        const section = node.closest("section");
        const anchor = section && section.id ? "#" + section.id : "#main";
        matches.push({ label, href: anchor });
      });
      try {
        const records = await getPublishedClubContent();
        records.forEach((record) => {
          const data = record.data || {};
          let label = "";
          let href = "#main";
          if (record.record_type === "player") {
            label = [data.name, data.position, data.squad_number].filter(Boolean).join(" · ");
            href = "players.html";
          } else if (record.record_type === "fixture") {
            label = [data.opponent, data.competition, data.match_date, data.venue, data.result, data.match_status].filter(Boolean).join(" · ");
            href = "#fixtures";
          } else if (record.record_type === "news") {
            label = [data.title, data.summary, data.category].filter(Boolean).join(" · ");
            href = "#news";
          } else if (record.record_type === "sponsor") {
            label = [data.name, data.support_type, data.details].filter(Boolean).join(" · ");
            href = "#sponsors";
          } else if (record.record_type === "activity") {
            label = [data.title, data.date, data.location].filter(Boolean).join(" · ");
            href = "#club";
          }
          if (label && label.toLocaleLowerCase().includes(query)) matches.push({ label, href });
        });
      } catch (_error) {
        searchResults.appendChild(makeElement("p", "", "Approved club updates are temporarily unavailable. Please try again."));
      }
      const unique = [];
      const seen = new Set();
      matches.forEach((item) => { const key = item.label + "|" + item.href; if (!seen.has(key)) { seen.add(key); unique.push(item); } });
      if (!unique.length) searchResults.appendChild(makeElement("p", "", "No public results found."));
      unique.slice(0, 12).forEach((item) => {
        const link = makeElement("a", "", item.label);
        link.href = item.href;
        searchResults.appendChild(link);
      });
    });
  }

  const yearElement = document.getElementById("current-year");
  if (yearElement) yearElement.textContent = String(new Date().getFullYear());
  loadMatchCentre();
  loadPublishedSections();
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
    const records = await getPublishedClubContent();
    const fixtures = records
      .filter((record) => record.record_type === "fixture")
      .map((record) => {
        const data = record.data || {};
        const home = data.match_type === "home" ? "Timau Union FC" : data.opponent;
        const away = data.match_type === "home" ? data.opponent : "Timau Union FC";
        return {
          id: record.id,
          opponent: data.opponent,
          home,
          away,
          date: data.match_date,
          venue: data.venue || "",
          result: String(data.result || "").trim(),
          competition: data.competition || "Club fixture",
          matchType: data.match_type,
          status: data.match_status
        };
      })
      .filter((match) => match.opponent && match.date && ["home", "away"].includes(match.matchType) &&
        ["scheduled", "completed", "postponed", "cancelled"].includes(match.status))
      .sort((a, b) => String(a.date).localeCompare(String(b.date)));

    if (!fixtures.length) {
      statusLabel.textContent = "No approved fixtures";
      notice.hidden = false;
      notice.textContent = "No approved fixtures or results are available yet.";
      return;
    }

    const today = new Date().toISOString().slice(0, 10);
    const upcoming = fixtures.filter((match) => match.status === "scheduled" && match.date >= today);
    const completed = fixtures.filter((match) => match.status === "completed").sort((a, b) => b.date.localeCompare(a.date));
    const featured = upcoming[0] || completed[0] || fixtures[fixtures.length - 1];

    const stylesheet = document.createElement("link");
    stylesheet.rel = "stylesheet";
    stylesheet.href = "css/match-centre.css";
    if (!document.querySelector('link[href="css/match-centre.css"]')) document.head.appendChild(stylesheet);

    clearChildren(feature);
    feature.appendChild(createFeatureHeading());
    const body = makeElement("div", "match-feature-body match-latest-body");
    body.appendChild(makeElement("p", "match-status", featured.status.toUpperCase()));
    body.appendChild(makeElement("p", "match-competition", featured.competition));
    body.appendChild(makeElement("h3", "matchup", featured.home + " vs " + featured.away));
    if (featured.result) body.appendChild(makeElement("span", "result-pill", featured.result));
    body.appendChild(makeElement("p", "match-date", formatMatchDate(featured.date)));
    if (featured.venue) body.appendChild(makeElement("p", "match-venue", featured.venue));
    feature.appendChild(body);
    const footer = makeElement("div", "match-feature-footer");
    footer.appendChild(makeElement("span", "","Timau Union FC"));
    footer.appendChild(makeElement("span", "", "Meru County, Kenya"));
    feature.appendChild(footer);

    statusLabel.textContent = featured.status === "completed" ? "Latest result" :
      featured.status === "scheduled" ? "Next fixture" : "Club match update";
    notice.hidden = true;

    const oldList = section.querySelector(".previous-results");
    if (oldList) oldList.remove();
    const others = fixtures.filter((match) => match.id !== featured.id)
      .sort((a, b) => b.date.localeCompare(a.date));
    if (others.length) {
      const previous = makeElement("section", "previous-results");
      previous.setAttribute("aria-labelledby", "previous-results-title");
      previous.appendChild(makeElement("h3", "previous-results-title", "Other fixtures & results"));
      const list = makeElement("ul", "previous-results-list");
      others.forEach((match) => {
        const item = makeElement("li", "previous-result-row");
        const details = makeElement("div", "previous-result-details");
        details.appendChild(makeElement("strong", "", match.home + " vs " + match.away));
        details.appendChild(makeElement("span", "", match.competition + " · " + match.status));
        details.appendChild(makeElement("span", "", formatMatchDate(match.date) + (match.venue ? " · " + match.venue : "")));
        item.appendChild(details);
        if (match.result) item.appendChild(makeElement("span", "result-pill", match.result));
        list.appendChild(item);
      });
      previous.appendChild(list);
      feature.insertAdjacentElement("afterend", previous);
    }
  } catch (_error) {
    statusLabel.textContent = "Updates temporarily unavailable";
    notice.hidden = false;
    notice.textContent = "Approved club updates could not be loaded. Please refresh to try again.";
  }
}

async function loadPublishedSections() {
  try {
    const records = await getPublishedClubContent();
    const news = records.filter((record) => record.record_type === "news");
    const sponsors = records.filter((record) => record.record_type === "sponsor");
    renderPublishedCards("news", news);
    renderPublishedCards("sponsors", sponsors);
  } catch (_error) {
    // Keep the explanatory empty states; never fall back to unapproved local content.
  }
}

function renderPublishedCards(sectionId, records) {
  const section = document.getElementById(sectionId);
  if (!section || !records.length) return;
  const placeholder = section.querySelector(sectionId === "news" ? ".news-placeholder" : ".sponsor-placeholder");
  if (placeholder) placeholder.hidden = true;
  let grid = section.querySelector(".published-record-grid");
  if (!grid) {
    grid = makeElement("div", "published-record-grid");
    grid.setAttribute("aria-live", "polite");
    section.querySelector(".container")?.appendChild(grid);
  }
  clearChildren(grid);
  records.slice(0, 6).forEach((record) => {
    const data = record.data || {};
    const card = makeElement("article", "published-record-card");
    if (sectionId === "news") {
      if (data.category) card.appendChild(makeElement("p", "eyebrow eyebrow-green", data.category));
      card.appendChild(makeElement("h3", "", data.title || "Club update"));
      const summary = String(data.summary || data.body || "").trim();
      if (summary) card.appendChild(makeElement("p", "", summary.slice(0, 700)));
    } else {
      card.appendChild(makeElement("h3", "", data.name || "Club partner"));
      if (data.support_type) card.appendChild(makeElement("p", "published-record-meta", data.support_type));
      if (data.details) card.appendChild(makeElement("p", "", data.details.slice(0, 700)));
      const href = safeExternalUrl(data.website);
      if (href) {
        const link = makeElement("a", "text-link", "Visit partner website");
        link.href = href;
        link.target = "_blank";
        link.rel = "noopener noreferrer";
        card.appendChild(link);
      }
    }
    grid.appendChild(card);
  });
}

function safeExternalUrl(value) {
  if (typeof value !== "string" || !value.trim()) return "";
  try {
    const url = new URL(value, location.origin);
    return ["http:", "https:"].includes(url.protocol) &&
      (value.startsWith("/") ? !value.startsWith("//") && url.origin === location.origin :
        /^https?:\/\//i.test(value)) ? url.href : "";
  } catch (_error) {
    return "";
  }
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
