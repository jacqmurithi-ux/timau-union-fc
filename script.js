
"use strict";

const menuToggle = document.getElementById("menu-toggle");
const primaryNav = document.getElementById("primary-nav");

if (menuToggle && primaryNav) {
  menuToggle.addEventListener("click", () => {
    const isOpen = primaryNav.classList.toggle("is-open");

    menuToggle.setAttribute("aria-expanded", String(isOpen));

    const label = menuToggle.querySelector(".menu-label");
    if (label) {
      label.textContent = isOpen ? "Close" : "Menu";
    }

    const icon = menuToggle.querySelector(".menu-icon");
    if (icon) {
      icon.textContent = isOpen ? "×" : "☰";
    }
  });

  primaryNav.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      primaryNav.classList.remove("is-open");
      menuToggle.setAttribute("aria-expanded", "false");

      const label = menuToggle.querySelector(".menu-label");
      if (label) label.textContent = "Menu";

      const icon = menuToggle.querySelector(".menu-icon");
      if (icon) icon.textContent = "☰";
    });
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      primaryNav.classList.remove("is-open");
      menuToggle.setAttribute("aria-expanded", "false");
      menuToggle.focus();

      const label = menuToggle.querySelector(".menu-label");
      if (label) label.textContent = "Menu";

      const icon = menuToggle.querySelector(".menu-icon");
      if (icon) icon.textContent = "☰";
    }
  });
}

const yearElement = document.getElementById("current-year");

if (yearElement) {
  yearElement.textContent = String(new Date().getFullYear());
}
