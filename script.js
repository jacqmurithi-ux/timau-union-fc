"use strict";

function initializePage() {
  // Shared public navigation is initialized by js/site-header.js on each public page.

  const searchToggle = document.getElementById("site-search-toggle");
  const searchPanel = document.getElementById("site-search-panel");
  const searchForm = document.getElementById("site-search-form");
  const searchInput = document.getElementById("site-search-input");
  const searchResults = document.getElementById("site-search-results");
  if (searchToggle && searchPanel && searchForm && searchInput && searchResults) {
    searchToggle.dataset.searchReady = "true";
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
        const [playersResponse, matchesResponse] = await Promise.all([
          fetch("data/players-2025-26.json", { cache: "no-store" }),
          fetch("data/matches.json", { cache: "no-store" })
        ]);
        if (playersResponse.ok) {
          const players = await playersResponse.json();
          const playerRows = Array.isArray(players) ? players : (Array.isArray(players.players) ? players.players : []);
          if (Array.isArray(playerRows)) playerRows.forEach((p) => {
            const name = String(p.name || p.player_name || "");
            const detail = [p.position, p.squad_number].filter(Boolean).join(" · ");
            if (name.toLocaleLowerCase().includes(query) || detail.toLocaleLowerCase().includes(query))
              matches.push({ label: [name, detail].filter(Boolean).join(" · "), href: "players.html" });
          });
        }
        if (matchesResponse.ok) {
          const games = await matchesResponse.json();
          if (Array.isArray(games)) games.forEach((m) => {
            const label = [m.home, m.away, m.competition, m.stage, m.venue, m.date, m.score].filter(Boolean).join(" · ");
            if (label.toLocaleLowerCase().includes(query) && isUsableMatch(m))
              matches.push({ label, href: "#fixtures" });
          });
        }
      } catch (_error) { /* Keep public page matches if optional data is unavailable. */ }
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
