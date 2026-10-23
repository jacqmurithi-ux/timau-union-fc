import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient(
  "https://owvvimydkjsjlrmnzvdi.supabase.co",
  "sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF",
  { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } }
);

let publishedContentPromise;

export async function getPublishedClubContent() {
  if (!publishedContentPromise) {
    publishedContentPromise = (async () => {
      const { data, error } = await db.rpc("get_published_club_content");
      if (error) throw new Error("Approved club updates are temporarily unavailable.");
      if (!Array.isArray(data)) throw new Error("The published-content response was invalid.");
      return data.filter((record) =>
        record && typeof record === "object" &&
        typeof record.record_type === "string" &&
        record.data && typeof record.data === "object" &&
        !Array.isArray(record.data)
      );
    })().catch((error) => {
      publishedContentPromise = null;
      throw error;
    });
  }
  return publishedContentPromise;
}
