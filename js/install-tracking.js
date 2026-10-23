/* PWA install handling is independent of optional anonymous analytics. */
(() => {
  "use strict";

  let deferredPrompt = null;
  let sendAnalytics = () => {};
  const diagnosticsKey = "tufc_install_analytics_diagnostics";
  function diagnostic(stage, status, detail = "") {
    const record = { stage, status, detail: String(detail || "").slice(0, 220), updatedAt: new Date().toISOString() };
    try { localStorage.setItem(diagnosticsKey, JSON.stringify(record)); } catch (_) {}
    window.dispatchEvent(new CustomEvent("timauanalyticsdiagnostic", { detail: record }));
  }
  diagnostic("tracker", "loaded", "Install tracker JavaScript ran.");

  // Register synchronously so a slow analytics module cannot miss this one-shot event.
  window.TimauPwaInstall = {
    available: () => Boolean(deferredPrompt),
    async prompt() {
      if (!deferredPrompt) return { outcome: "unavailable" };
      const event = deferredPrompt;
      deferredPrompt = null;
      try {
        await event.prompt();
        const choice = await event.userChoice;
        if (choice?.outcome === "accepted") sendAnalytics("install_prompt_accepted");
        return { outcome: choice?.outcome || "unknown" };
      } catch (_) {
        return { outcome: "error" };
      }
    }
  };

  window.addEventListener("beforeinstallprompt", event => {
    event.preventDefault();
    deferredPrompt = event;
    sendAnalytics("install_prompt_shown");
    window.dispatchEvent(new Event("timauinstallpromptready"));
  });

  window.addEventListener("appinstalled", () => {
    deferredPrompt = null;
    sendAnalytics("install");
  });

  // Analytics are optional; privacy controls or a network failure must not disable installation.
  const dnt = navigator.doNotTrack === "1" || window.doNotTrack === "1" ||
    navigator.globalPrivacyControl === true;
  if (dnt) { diagnostic("privacy", "opted_out", "Do Not Track or Global Privacy Control is enabled; no analytics will be sent."); return; }

  const source = location.pathname.startsWith("/app/") ? "app" : "home";
  let visitor;
  try {
    const key = "tufc_analytics_visitor_id";
    visitor = localStorage.getItem(key);
    if (!visitor || !/^[0-9a-f-]{36}$/i.test(visitor)) {
      visitor = crypto.randomUUID();
      localStorage.setItem(key, visitor);
    }
  } catch (error) {
    console.warn("[Timau install analytics] Local visitor storage unavailable; analytics disabled for this browser.", error?.message || error);
    diagnostic("storage", "failed", error?.message || "Local visitor storage is unavailable.");
    return;
  }

  diagnostic("storage", "ready", "Local storage is available; no visitor identifier is displayed here.");
  import("https://esm.sh/@supabase/supabase-js@2").then(({ createClient }) => {
    const db = createClient(
      "https://owvvimydkjsjlrmnzvdi.supabase.co",
      "sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF",
      { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } }
    );
    diagnostic("supabase_client", "ready", "Supabase client loaded.");
    sendAnalytics = type => {
      const onceKey = type === "install_prompt_shown" ? "tufc_prompt_shown" :
        type === "install_prompt_accepted" ? "tufc_prompt_accepted" :
        type === "app_open" ? "tufc_app_open_sent" : null;
      if (onceKey) {
        try {
          if (sessionStorage.getItem(onceKey) === "1") return;
          sessionStorage.setItem(onceKey, "1");
        } catch (error) {
          // Storage restrictions should not prevent the event from being sent.
          console.warn("[Timau install analytics] Session storage unavailable; event deduplication may be limited.", error?.message || error);
        }
      }
      diagnostic(type, "attempted", "Sending event to the protected analytics function.");
      void db.rpc("record_event", {
        _event_type: type,
        _visitor_id: visitor,
        _source: source
      }).then(({ error }) => {
        if (error) {
          diagnostic(type, "rejected", error.message || error.code || "Supabase rejected the event.");
          console.warn("[Timau install analytics] Event rejected by Supabase:", type, error.message || error.code || "unknown error");
        } else {
          diagnostic(type, "accepted", "Supabase accepted the event.");
        }
      }).catch(error => {
        diagnostic(type, "network_error", error?.message || "Network/request failure.");
        console.warn("[Timau install analytics] Network/request failure:", type, error?.message || error);
      });
    };
    const standalone = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
    diagnostic("launch_mode", standalone ? "standalone" : "browser", standalone
      ? "App is running in installed/standalone mode."
      : "This page is running in a browser tab; app_open is sent only in installed mode.");
    if (standalone) sendAnalytics("app_open");
    // If the browser event happened before analytics loaded, count it once analytics is ready.
    if (deferredPrompt) sendAnalytics("install_prompt_shown");
  }).catch(error => {
    diagnostic("supabase_client", "failed", error?.message || "Supabase client failed to load; check network access to esm.sh.");
    console.warn("[Timau install analytics] Supabase client failed to load; check network access to esm.sh.", error?.message || error);
  });
})();
