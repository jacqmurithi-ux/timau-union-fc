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
  return Response.json({ processed: results.length, results });
});
