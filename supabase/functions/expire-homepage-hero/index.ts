import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return new Response("Server configuration missing", { status: 500 });
  const auth = req.headers.get("authorization") || "";
  if (auth !== "Bearer " + serviceKey) return new Response("Unauthorized", { status: 401 });
  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: expired, error } = await db.from("homepage_hero_slides")
    .select("id,image_path,caption").not("ends_at", "is", null).lte("ends_at", new Date().toISOString()).limit(100);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  const results: { id: string; status: string }[] = [];
  for (const slide of expired || []) {
    const { error: storageError } = await db.storage.from("homepage-hero").remove([slide.image_path]);
    if (storageError) { results.push({ id: slide.id, status: "storage_delete_failed" }); continue; }
    const { data: removed, error: removeError } = await db.rpc("homepage_hero_expire", { _slide_id: slide.id });
    results.push({ id: slide.id, status: removeError ? "record_delete_failed" : removed ? "expired" : "already_removed" });
  }
  // Remove orphaned uploads/replaced files after a one-hour grace period.
  // Keep files referenced by any slide row, including expired rows whose deletion failed.
  const { data: rows } = await db.from("homepage_hero_slides").select("image_path");
  const referenced = new Set((rows || []).map((row) => row.image_path));
  const cutoff = Date.now() - 60 * 60 * 1000;
  const { data: folders } = await db.storage.from("homepage-hero").list("", { limit: 1000 });
  for (const folder of folders || []) {
    if (!folder.id) {
      const { data: objects } = await db.storage.from("homepage-hero").list(folder.name, { limit: 1000 });
      const orphanPaths = (objects || []).filter((obj) => {
        if (!obj.id) return false;
        const path = folder.name + "/" + obj.name;
        const created = Date.parse(obj.created_at || obj.updated_at || "");
        return !referenced.has(path) && Number.isFinite(created) && created < cutoff;
      }).map((obj) => folder.name + "/" + obj.name);
      if (orphanPaths.length) {
        const { error: orphanError } = await db.storage.from("homepage-hero").remove(orphanPaths);
        results.push({ id: folder.name, status: orphanError ? "orphan_cleanup_failed" : "orphans_removed:" + orphanPaths.length });
      }
    }
  }
  return Response.json({ processed: results.length, results });
});
