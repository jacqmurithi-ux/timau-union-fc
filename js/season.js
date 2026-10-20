"use strict";

document.addEventListener("DOMContentLoaded", () => {
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

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = String(text);
    return node;
  }

  function appendText(parent, tag, className, text) {
    const node = element(tag, className, text);
    parent.appendChild(node);
    return node;
  }

  function ordinal(number) {
    const mod100 = number % 100;
    if (mod100 >= 11 && mod100 <= 13) return number + "th";
    switch (number % 10) {
      case 1: return number + "st";
      case 2: return number + "nd";
      case 3: return number + "rd";
      default: return number + "th";
    }
  }

  function counter(parent, value, format = "number", className = "") {
    const node = element("span", className, reducedMotion ? formatValue(value, format) : "0");
    node.dataset.counter = String(value);
    node.dataset.counterFormat = format;
    parent.appendChild(node);
    return node;
  }

  function formatValue(value, format) {
    if (format === "ordinal") return ordinal(value);
    if (format === "signed") return value > 0 ? "+" + value : String(value);
    return String(value);
  }

  function activateCounters(root) {
    const nodes = root.querySelectorAll("[data-counter]");
    if (!nodes.length) return;
    if (reducedMotion || !("IntersectionObserver" in window)) {
      nodes.forEach((node) => {
        node.textContent = formatValue(Number(node.dataset.counter), node.dataset.counterFormat);
      });
      return;
    }
    const observer = new IntersectionObserver((entries, activeObserver) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        const node = entry.target;
        const target = Number(node.dataset.counter);
        const format = node.dataset.counterFormat;
        activeObserver.unobserve(node);
        const duration = 650;
        const start = performance.now();
        const step = (now) => {
          const progress = Math.min((now - start) / duration, 1);
          const eased = 1 - Math.pow(1 - progress, 3);
          node.textContent = formatValue(Math.round(target * eased), format);
          if (progress < 1) window.requestAnimationFrame(step);
        };
        window.requestAnimationFrame(step);
      });
    }, { threshold: 0.35 });
    nodes.forEach((node) => observer.observe(node));
  }

  function metricCard(label, value, format = "number", detail = "") {
    const card = element("article", "season-metric-card season-reveal");
    appendText(card, "span", "season-metric-label", label);
    const valueNode = element("strong", "season-metric-value");
    if (Array.isArray(value)) {
      value.forEach((part, index) => {
        if (index > 0) valueNode.append(" / ");
        counter(valueNode, Number(part), "number");
      });
    } else if (Number.isFinite(Number(value))) {
      counter(valueNode, Number(value), format);
    } else {
      valueNode.textContent = String(value);
    }
    card.appendChild(valueNode);
    if (detail) appendText(card, "span", "season-metric-detail", detail);
    return card;
  }

  function makeSummary(target, team, compact = false) {
    if (!target) return;
    target.replaceChildren();
    const position = element("div", "season-position-badge");
    appendText(position, "span", "season-position-label", "FINAL POSITION");
    const pos = element("strong", "season-position-number");
    counter(pos, team.position, "ordinal");
    position.appendChild(pos);
    target.appendChild(position);

    const metrics = element("div", "season-summary-metrics");
    const record = element("article", "season-summary-stat");
    appendText(record, "span", "season-metric-label", "W–D–L");
    const recordValue = element("strong", "season-summary-stat-value");
    counter(recordValue, team.wins);
    recordValue.append("–");
    counter(recordValue, team.draws);
    recordValue.append("–");
    counter(recordValue, team.losses);
    record.appendChild(recordValue);
    metrics.appendChild(record);
    metrics.appendChild(metricCard("Points", team.points));
    metrics.appendChild(metricCard("Goals for / against", [team.goalsFor, team.goalsAgainst]));
    metrics.appendChild(metricCard("Goal difference", team.goalDifference, "signed"));
    target.appendChild(metrics);
    if (!compact) target.classList.add("season-summary-full");
    activateCounters(target);
  }

  function makeTableRow(team, compact) {
    const row = element("tr", team.team === "Timau Union FC" ? "is-timau" : "");
    if (team.team === "Timau Union FC") row.setAttribute("aria-current", "true");
    const values = compact
      ? [team.position, team.team, team.played, team.goalDifference, team.points]
      : [team.position, team.team, team.played, team.wins, team.draws, team.losses, team.goalsFor, team.goalsAgainst, team.goalDifference, team.points];
    values.forEach((value, index) => {
      const cell = element(index === 1 ? "th" : "td", "");
      if (index === 0) {
        cell.classList.add("sticky-pos");
      } else if (index === 1) {
        cell.scope = "row";
        cell.classList.add("sticky-team");
      } else if (index === values.length - 1) {
        cell.classList.add("season-points-cell");
      }
      cell.textContent = index === 1 ? value : (index === (compact ? 3 : 8) ? (Number(value) > 0 ? "+" + value : String(value)) : String(value));
      row.appendChild(cell);
    });
    return row;
  }

  function renderTable(target, teams, compact) {
    if (!target) return;
    target.replaceChildren();
    teams.forEach((team) => target.appendChild(makeTableRow(team, compact)));
  }

  function revealOnScroll() {
    const nodes = document.querySelectorAll(".season-reveal");
    if (reducedMotion || !("IntersectionObserver" in window)) {
      nodes.forEach((node) => node.classList.add("is-visible"));
      return;
    }
    const observer = new IntersectionObserver((entries, activeObserver) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          activeObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12 });
    nodes.forEach((node) => observer.observe(node));
  }

  function formatDate(dateString) {
    const date = new Date(dateString + "T00:00:00");
    if (Number.isNaN(date.getTime())) return dateString;
    return new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric" }).format(date);
  }

  function renderSource(target, data) {
    if (!target) return;
    target.replaceChildren();
    target.append("Source: ");
    const link = element("a", "", data.source.label);
    link.href = data.source.url;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    target.appendChild(link);
    target.append(" · Last updated: " + formatDate(data.lastUpdated));
  }

  function renderHomeAway(data) {
    const target = document.getElementById("home-away-cards");
    if (!target) return;
    target.replaceChildren();
    const records = [
      { label: "Home", data: data.timauUnion.home, tone: "home" },
      { label: "Away", data: data.timauUnion.away, tone: "away" }
    ];
    const maxPoints = Math.max(...records.map((record) => record.data.points), 1);
    records.forEach((record) => {
      const card = element("article", "home-away-card season-reveal");
      appendText(card, "p", "home-away-kicker", record.label + " record");
      const heading = element("div", "home-away-heading");
      appendText(heading, "h3", "", record.label);
      const points = element("strong", "home-away-points");
      counter(points, record.data.points);
      points.append(" pts");
      heading.appendChild(points);
      card.appendChild(heading);
      const barTrack = element("div", "home-away-bar-track");
      barTrack.setAttribute("role", "img");
      barTrack.setAttribute("aria-label", record.label + " earned " + record.data.points + " points out of " + maxPoints + " points across the two records");
      const bar = element("span", "home-away-bar " + record.tone);
      bar.style.width = (record.data.points / maxPoints * 100) + "%";
      barTrack.appendChild(bar);
      card.appendChild(barTrack);
      const line = element("p", "home-away-record", record.data.wins + "W · " + record.data.draws + "D · " + record.data.losses + "L");
      card.appendChild(line);
      appendText(card, "p", "home-away-detail", record.data.played + " played · " + record.data.goalsFor + " goals for · " + record.data.goalsAgainst + " against");
      target.appendChild(card);
    });
    activateCounters(target);
  }

  function renderKeyStats(data, team) {
    const target = document.getElementById("season-key-stats");
    if (!target) return;
    const standings = data.standings;
    const first = standings.find((row) => row.position === 1);
    const third = standings.find((row) => row.position === 3);
    const concededSorted = [...standings].sort((a, b) => a.goalsAgainst - b.goalsAgainst || a.position - b.position);
    const scoredSorted = [...standings].sort((a, b) => b.goalsFor - a.goalsFor || a.position - b.position);
    const concededRank = concededSorted.findIndex((row) => row.team === team.team) + 1;
    const scoredRank = scoredSorted.findIndex((row) => row.team === team.team) + 1;
    target.replaceChildren();
    target.appendChild(metricCard("Gap to first", first.points - team.points, "number", "points behind the leaders"));
    target.appendChild(metricCard("Ahead of third", team.points - third.points, "number", "points clear of third place"));
    target.appendChild(metricCard("Goals conceded rank", concededRank, "ordinal", team.goalsAgainst + " conceded"));
    target.appendChild(metricCard("Goals scored rank", scoredRank, "ordinal", team.goalsFor + " scored"));
    activateCounters(target);

    const discipline = document.getElementById("discipline-summary");
    if (discipline) {
      discipline.replaceChildren();
      appendText(discipline, "h3", "", "Discipline");
      const list = element("dl", "discipline-list");
      [
        ["Yellow cards", data.timauUnion.cards.yellow],
        ["Second-yellow reds", data.timauUnion.cards.secondYellowRed],
        ["Straight reds", data.timauUnion.cards.straightRed]
      ].forEach(([label, value]) => {
        const item = element("div", "discipline-item");
        appendText(item, "dt", "", label);
        appendText(item, "dd", "", value);
        list.appendChild(item);
      });
      discipline.appendChild(list);
    }
  }

  function renderForm(data) {
    const target = document.getElementById("season-form");
    if (!target) return;
    target.replaceChildren();
    const labels = { W: "Win", D: "Draw", L: "Loss" };
    data.timauUnion.recentForm.results.forEach((result, index) => {
      const pill = element("span", "form-pill form-" + result.toLowerCase(), result);
      pill.setAttribute("role", "img");
      pill.setAttribute("aria-label", "Result " + (index + 1) + ": " + (labels[result] || "Unknown"));
      pill.title = labels[result] || "Unknown result";
      target.appendChild(pill);
    });
    const note = document.getElementById("season-form-note");
    if (note) {
      note.textContent = data.timauUnion.recentForm.orderConfirmed
        ? "Results are shown from oldest to newest."
        : "The result sequence was supplied for this summary, but the exact match-by-match order has not been independently confirmed.";
    }
  }

  function renderFinalResult(data) {
    const target = document.getElementById("final-result-card");
    if (!target) return;
    const match = data.timauUnion.finalMatch;
    target.replaceChildren();
    appendText(target, "p", "final-result-label", "FINAL MATCH");
    appendText(target, "p", "final-result-date", match.dateLabel || formatDate(match.date));
    const scoreline = element("div", "final-scoreline");
    appendText(scoreline, "span", "final-team final-home-team", match.homeTeam);
    const score = element("strong", "final-score", match.homeScore + " – " + match.awayScore);
    score.setAttribute("aria-label", match.homeScore + " to " + match.awayScore);
    scoreline.appendChild(score);
    appendText(scoreline, "span", "final-team final-away-team", match.awayTeam);
    target.appendChild(scoreline);
    appendText(target, "p", "final-result-venue", match.venue);
  }

  function showError() {
    const fullError = document.getElementById("season-error");
    const homeError = document.getElementById("season-home-error");
    if (fullError) fullError.hidden = false;
    if (homeError) homeError.hidden = false;
    ["season-home-summary", "season-home-table", "season-summary", "season-full-table", "home-away-cards", "season-key-stats", "season-form", "final-result-card"].forEach((id) => {
      const node = document.getElementById(id);
      if (node) node.replaceChildren(element("p", "season-loading", "Season data could not be loaded. Please try again later."));
    });
  }

  fetch("data/season-2025-26.json")
    .then((response) => {
      if (!response.ok) throw new Error("Season data request failed");
      return response.json();
    })
    .then((data) => {
      if (!data || !Array.isArray(data.standings) || !data.timauUnion || !data.source) {
        throw new Error("Season data format is invalid");
      }
      const team = data.standings.find((row) => row.team === data.timauUnion.team);
      if (!team) throw new Error("Timau Union FC was not found in standings");

      makeSummary(document.getElementById("season-home-summary"), team, true);
      renderTable(document.getElementById("season-home-table"), data.standings.slice(0, 5), true);
      renderSource(document.getElementById("season-home-source"), data);
      makeSummary(document.getElementById("season-summary"), team);
      renderTable(document.getElementById("season-full-table"), data.standings, false);
      renderSource(document.getElementById("season-source"), data);
      renderHomeAway(data);
      renderKeyStats(data, team);
      renderForm(data);
      renderFinalResult(data);
      revealOnScroll();
    })
    .catch((error) => {
      console.warn("Unable to load season data.", error);
      showError();
    });
});
