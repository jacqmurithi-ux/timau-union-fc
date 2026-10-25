(()=> {
  const config = window.TIMAU_SPONSORSHIP_CONFIG || {};
  const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[char]));
  const safeUrl = value => {
    try {
      const url = new URL(value);
      return ["http:", "https:"].includes(url.protocol) ? url.href : "";
    } catch {
      return "";
    }
  };
  document.addEventListener("DOMContentLoaded", async () => {
    const targets = [...document.querySelectorAll("[data-public-partners]")];
    if (!targets.length) return;
    const emptyState = '<p class="partner-empty-state">No public partners have been announced yet. Interested in partnering with the club? Use the enquiry options above.</p>';
    const unavailableState = '<p class="partner-empty-state">Approved partner information is temporarily unavailable. You can still enquire about partnering with the club above.</p>';
    targets.forEach(target => { target.innerHTML = emptyState; });
    if (!config.supabaseUrl || !config.supabasePublishableKey) {
      targets.forEach(target => { target.innerHTML = unavailableState; });
      return;
    }
    try {
      const response = await fetch(config.supabaseUrl + "/rest/v1/public_partners?select=name,support_type,public_description,website,fan_offer_text&order=name.asc", {
        headers: {
          apikey: config.supabasePublishableKey,
          Authorization: "Bearer " + config.supabasePublishableKey
        }
      });
      if (!response.ok) throw new Error("Public partner request failed");
      const rows = await response.json();
      targets.forEach(target => {
        const list = target.dataset.offers === "true" ? rows.filter(row => row.fan_offer_text) : rows;
        target.innerHTML = list.length ? list.map(row =>
          '<article class="partner-card"><h3>' + escapeHtml(row.name) + '</h3>' +
          (row.support_type ? '<p><strong>' + escapeHtml(row.support_type) + '</strong></p>' : '') +
          (row.public_description ? '<p>' + escapeHtml(row.public_description) + '</p>' : '') +
          (target.dataset.offers === "true" && row.fan_offer_text ? '<p>' + escapeHtml(row.fan_offer_text) + '</p>' : '') +
          (safeUrl(row.website) ? '<a class="button button-outline" href="' + escapeHtml(safeUrl(row.website)) + '" target="_blank" rel="noopener noreferrer">Visit partner</a>' : '') +
          '</article>'
        ).join("") : emptyState;
      });
    } catch {
      targets.forEach(target => { target.innerHTML = unavailableState; });
    }
  });
})();