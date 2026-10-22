/* Shared public-site navigation. Kept separate from homepage-only search/content scripts. */
(() => {
  "use strict";

  const initializeNavigation = () => {
    const menuToggle = document.getElementById("menu-toggle");
    const primaryNav = document.getElementById("primary-nav");
    if (!menuToggle || !primaryNav || menuToggle.dataset.navigationReady === "true") return;

    menuToggle.dataset.navigationReady = "true";
    const menuIcon = menuToggle.querySelector(".menu-icon");

    const closeButton = document.createElement("button");
    closeButton.type = "button";
    closeButton.className = "primary-nav-close";
    closeButton.setAttribute("aria-label", "Close navigation menu");
    closeButton.textContent = "×  Close menu";
    primaryNav.prepend(closeButton);

    let menuOpen = false;

    const setMenuState = (isOpen, returnFocus = false) => {
      menuOpen = isOpen;
      primaryNav.classList.toggle("is-open", isOpen);
      menuToggle.setAttribute("aria-expanded", String(isOpen));
      menuToggle.setAttribute("aria-label", isOpen ? "Close navigation menu" : "Open navigation menu");

      if (menuIcon) {
        menuIcon.textContent = isOpen ? "×" : "☰";
        menuIcon.setAttribute("aria-hidden", "true");
      }

      document.documentElement.classList.toggle("navigation-open", isOpen);
      document.body.classList.toggle("navigation-open", isOpen);

      if (returnFocus) menuToggle.focus();
    };

    setMenuState(false);

    menuToggle.addEventListener("click", (event) => {
      event.preventDefault();
      setMenuState(!menuOpen);
    });

    closeButton.addEventListener("click", () => setMenuState(false));

    primaryNav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => setMenuState(false));
    });

    document.addEventListener("pointerdown", (event) => {
      if (!menuOpen) return;
      if (primaryNav.contains(event.target) || menuToggle.contains(event.target)) return;
      setMenuState(false);
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && menuOpen) {
        setMenuState(false, true);
      }
    });

    // Prevent background touch scrolling on mobile Safari while preserving
    // scrolling inside the open navigation panel itself.
    document.addEventListener("touchmove", (event) => {
      if (!menuOpen) return;
      if (primaryNav.contains(event.target) || menuToggle.contains(event.target)) return;
      event.preventDefault();
    }, { passive: false });

    const desktopLayout = window.matchMedia("(min-width: 900px)");
    const handleLayoutChange = (event) => {
      if (event.matches && menuOpen) setMenuState(false);
    };
    if (desktopLayout.addEventListener) {
      desktopLayout.addEventListener("change", handleLayoutChange);
    } else {
      desktopLayout.addListener(handleLayoutChange);
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeNavigation, { once: true });
  } else {
    initializeNavigation();
  }
})();
