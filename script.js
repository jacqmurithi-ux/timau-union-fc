
"use strict";

document.addEventListener("DOMContentLoaded", () => {
  const menuToggle = document.getElementById("menu-toggle");
  const primaryNav = document.getElementById("primary-nav");

  /**
   * Update the mobile navigation's open/closed state.
   */
  if (menuToggle && primaryNav) {
    const menuLabel = menuToggle.querySelector(".menu-label");
    const menuIcon = menuToggle.querySelector(".menu-icon");

    const setMenuState = (isOpen, returnFocus = false) => {
      primaryNav.classList.toggle("is-open", isOpen);

      menuToggle.setAttribute("aria-expanded", String(isOpen));

      if (menuLabel) {
        menuLabel.textContent = isOpen ? "Close" : "Menu";
      }

      if (menuIcon) {
        menuIcon.textContent = isOpen ? "×" : "☰";
        menuIcon.setAttribute("aria-hidden", "true");
      }

      if (returnFocus) {
        menuToggle.focus();
      }
    };

    menuToggle.addEventListener("click", () => {
      const isOpen =
        menuToggle.getAttribute("aria-expanded") !== "true";

      setMenuState(isOpen);
    });

    // Close the mobile menu after a navigation link is selected.
    primaryNav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        setMenuState(false);
      });
    });

    // Allow keyboard users to dismiss the menu with Escape.
    document.addEventListener("keydown", (event) => {
      if (
        event.key === "Escape" &&
        primaryNav.classList.contains("is-open")
      ) {
        setMenuState(false, true);
      }
    });

    // Close the menu when switching to a desktop-sized layout.
    const desktopLayout = window.matchMedia("(min-width: 768px)");

    const handleLayoutChange = (event) => {
      if (event.matches) {
        setMenuState(false);
      }
    };

    if (desktopLayout.addEventListener) {
      desktopLayout.addEventListener("change", handleLayoutChange);
    } else {
      // Compatibility with older browsers.
      desktopLayout.addListener(handleLayoutChange);
    }
  }

  /**
   * Keep the footer year current automatically.
   */
  const yearElement = document.getElementById("current-year");

  if (yearElement) {
    yearElement.textContent = String(new Date().getFullYear());
  }
});
