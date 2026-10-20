"use strict";
document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.getElementById("menu-toggle");
  const nav = document.getElementById("primary-nav");
  if (toggle && nav) {
    const label = toggle.querySelector(".menu-label");
    const icon = toggle.querySelector(".menu-icon");
    const setOpen = (open) => {
      nav.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", String(open));
      if (label) label.textContent = open ? "Close" : "Menu";
      if (icon) icon.textContent = open ? "×" : "☰";
    };
    toggle.addEventListener("click", () => setOpen(toggle.getAttribute("aria-expanded") !== "true"));
    nav.querySelectorAll("a").forEach((link) => link.addEventListener("click", () => setOpen(false)));
    document.addEventListener("keydown", (event) => { if (event.key === "Escape") setOpen(false); });
    const mq = window.matchMedia("(min-width: 900px)");
    if (mq.addEventListener) mq.addEventListener("change", (event) => { if (event.matches) setOpen(false); });
  }
  const year = document.getElementById("current-year");
  if (year) year.textContent = String(new Date().getFullYear());
  const grid = document.getElementById("players-grid");
  const count = document.getElementById("players-count");
  const error = document.getElementById("players-error");
  const source = document.getElementById("players-source");
  const search = document.getElementById("player-search");
  const status = document.getElementById("players-status");
  let players = [];
  function render(list) {
    grid.replaceChildren();
    list.forEach((player) => {
      const card = document.createElement("article");
      card.className = "player-card";
      const crest = document.createElement("img");
      crest.className = "player-card-crest";
      crest.src = "assets/club-crest.jpg";
      crest.alt = "";
      crest.width = 56;
      crest.height = 56;
      crest.loading = "lazy";
      const number = document.createElement("span");
      number.className = "player-card-number";
      number.textContent = String(player.number).padStart(2, "0");
      const name = document.createElement("h2");
      name.className = "player-card-name";
      name.textContent = player.name;
      const badge = document.createElement("span");
      badge.className = "player-status";
      badge.textContent = "Squad";
      card.append(crest, number, name, badge);
      grid.appendChild(card);
    });
    if (count) count.textContent = list.length + (list.length === 1 ? " player listed" : " players listed");
    if (status) status.textContent = list.length ? "" : "No players match your search.";
  }
  if (search) search.addEventListener("input", () => {
    const term = search.value.trim().toLocaleLowerCase();
    render(players.filter((player) => player.name.toLocaleLowerCase().includes(term)));
  });
  fetch("data/players-2025-26.json")
    .then((response) => { if (!response.ok) throw new Error("Roster unavailable"); return response.json(); })
    .then((data) => {
      if (!data || !Array.isArray(data.players)) throw new Error("Roster data is invalid");
      players = data.players.filter((player) => player.status === "listed");
      render(players);
      const link = document.createElement("a");
      link.href = data.source.url;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = data.source.label;
      source.append("Roster source: ", link, " · Season: " + data.season + " · Updated: " + data.lastUpdated);
    })
    .catch(() => {
      if (error) error.hidden = false;
      if (grid) grid.replaceChildren();
      if (count) count.textContent = "Roster unavailable";
    });
});
