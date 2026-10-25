import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const db=createClient("https://owvvimydkjsjlrmnzvdi.supabase.co","sb_publishable_fLCaYsS1Pbp1Kd9blLXHSA_s-_9NNtF");
const mount=document.querySelector("[data-sponsor-mockups-public]");if(mount){mount.innerHTML="<p>Approved sponsorship mockups will appear here after the club enables public publication for this library.</p>";}
