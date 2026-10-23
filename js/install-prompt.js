(() => {
  "use strict";

  const DISPLAY_MS = 5000;
  const FADE_MS = 250;
  let timer = 0;
  let toast = null;
  let dismissed = false;

  function makeToast() {
    if (toast) return toast;
    toast = document.createElement("aside");
    toast.className = "install-toast";
    toast.setAttribute("role", "status");
    toast.setAttribute("aria-live", "polite");
    toast.innerHTML = '<span class="install-toast-icon" aria-hidden="true">⬇</span>' +
      '<span class="install-toast-copy"><strong>Install Timau Union FC</strong>' +
      '<small>Add the club app to your home screen.</small></span>' +
      '<button class="install-toast-action" type="button">Install</button>' +
      '<button class="install-toast-close" type="button" aria-label="Dismiss install prompt">×</button>';
    document.body.appendChild(toast);

    toast.querySelector(".install-toast-action").addEventListener("click", async () => {
      const install = window.TimauPwaInstall;
      if (!install || !install.available()) {
        hideToast();
        return;
      }
      const action = toast.querySelector(".install-toast-action");
      action.disabled = true;
      action.textContent = "Opening…";
      const result = await install.prompt();
      if (result.outcome === "accepted" || result.outcome === "dismissed") hideToast();
      else {
        action.disabled = false;
        action.textContent = "Try again";
      }
    });
    toast.querySelector(".install-toast-close").addEventListener("click", () => {
      dismissed = true;
      hideToast();
    });
    return toast;
  }

  function showToast() {
    if (dismissed || window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true) return;
    if (!window.TimauPwaInstall || !window.TimauPwaInstall.available()) return;
    const node = makeToast();
    clearTimeout(timer);
    node.hidden = false;
    requestAnimationFrame(() => node.classList.add("is-visible"));
    timer = window.setTimeout(hideToast, DISPLAY_MS);
  }

  function hideToast() {
    if (!toast || toast.hidden) return;
    clearTimeout(timer);
    toast.classList.remove("is-visible");
    window.setTimeout(() => {
      if (toast && !toast.classList.contains("is-visible")) toast.hidden = true;
    }, FADE_MS);
  }

  window.addEventListener("beforeinstallprompt", () => {
    // Let install-tracking.js capture the event before checking availability.
    window.setTimeout(showToast, 0);
  });

  // In case this script loads after the browser has already dispatched the event.
  window.addEventListener("load", () => window.setTimeout(showToast, 100));
})();
