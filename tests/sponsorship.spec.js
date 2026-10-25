import { test, expect } from "@playwright/test";

test("partnership page renders and public partners container is present on desktop", async ({ page }) => {
  await page.setViewportSize({ width: 1365, height: 900 });
  await page.goto("/partnership.html");
  await expect(page.getByRole("heading", { name: "Partner with Timau Union FC" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Our approved partners" })).toBeVisible();
  await expect(page.locator("[data-public-partners]")).toBeVisible();
  await expect(page.getByRole("link", { name: "Register interest" }).first()).toHaveAttribute("href", "/register-interest.html");
});

test("partnership page remains usable on a narrow mobile viewport", async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 800 });
  await page.goto("/partnership.html");
  await expect(page.getByRole("heading", { name: "Partner with Timau Union FC" })).toBeVisible();
  await expect(page.locator("body")).toHaveJSProperty("scrollWidth", 360);
  await expect(page.getByRole("link", { name: "Register interest" }).first()).toBeVisible();
});

test("interest links preselect the requested category", async ({ page }) => {
  await page.goto("/register-interest.html?interest=Kit");
  await expect(page.getByRole("heading", { name: "Register your interest" })).toBeVisible();
  await expect(page.locator('input[name="interests"][value="Kit"]')).toBeChecked();
});

test("interest form validates and submits through the RPC client", async ({ page }) => {
  await page.route("https://esm.sh/@supabase/supabase-js@2", route => route.fulfill({
    status: 200,
    contentType: "application/javascript",
    body: `export function createClient(){return {rpc:async(name,args)=>{window.__sponsorRpc={name,args};return {data:"test-enquiry-id",error:null}}}}`
  }));
  await page.goto("/register-interest.html");
  await page.getByRole("button", { name: "Register interest" }).click();
  await expect(page.getByRole("alert")).toContainText("Please check your name");
  await page.getByLabel("Name *").fill("Test Person");
  await page.getByLabel("Email *").fill("test@example.com");
  await page.getByLabel("Business *").fill("Test Business");
  await page.locator('input[name="interests"][value="Kit"]').check();
  await page.waitForTimeout(2600);
  await page.getByRole("button", { name: "Register interest" }).click();
  await expect(page.getByRole("status")).toContainText("Thank you");
  await expect.poll(() => page.evaluate(() => window.__sponsorRpc?.name)).toBe("submit_sponsor_enquiry");
});

test("Sponsor Lead can view and mark a mocked enquiry as contacted", async ({ page }) => {
  await page.route("**/private-nav.js*", route => route.abort());
  await page.route("https://esm.sh/@supabase/supabase-js@2", route => route.fulfill({
    status: 200,
    contentType: "application/javascript",
    body: `
      window.__sponsorState={enquiries:[{id:"enq-1",name:"Test Contact",email:"contact@example.com",business:"Test Business",phone:"0712345678",interests:["Kit"],message:"Test enquiry",status:"new",created_at:"2026-10-25T10:00:00Z"}]};
      export function createClient(){return {
        auth:{getSession:async()=>({data:{session:{user:{id:"test-user"}}},error:null}),signOut:async()=>({error:null})},
        rpc:async(name,args={})=>{if(name==='sponsor_enquiry_set_status'){const row=window.__sponsorState.enquiries.find(x=>x.id===args._enquiry_id);if(row)row.status=args._status;window.__sponsorState.statusCall=args;return {data:null,error:null}}const data={
          sponsor_packages_seed_starters:null,
          sponsor_lead_get_workspace:{roles:["sponsor_lead"],is_admin:false},
          sponsor_lead_get_portal_notifications:[],
          sponsor_eval_get_workspace:{settings:{},evaluations:[],templates:[],proposals:[],proposal_versions:[],is_chairman:false},
          club_get_workspace_bundle:{records:[]}
        }[name];return {data,error:null}},
        from:()=>({select(){return this},order(){return this},limit:async()=>({data:window.__sponsorState.enquiries,error:null}),update(payload){return {eq:async(_field,id)=>{const row=window.__sponsorState.enquiries.find(x=>x.id===id);if(row)Object.assign(row,payload);return {error:null}}}}})
      }}
    `
  }));
  await page.goto("/app/sponsor-lead.html");
  await expect(page.getByText("Sponsor workspace loaded.")).toBeVisible();
  await page.getByRole("tab", { name: "Enquiries" }).click();
  await expect(page.getByText("Test Business — Test Contact")).toBeVisible();
  await page.locator('[data-enquiry-status-select="enq-1"]').selectOption("in_discussion");
  await page.evaluate(() => window.prompt = () => "Sponsor discussion is underway");
  await page.getByRole("button", { name: "Save progress" }).click();
  await expect(page.getByText(/Status: in discussion/)).toBeVisible();
  await expect(page.getByText(/No account is created or invited from this enquiry/)).toHaveCount(0);
  await expect.poll(() => page.evaluate(() => window.__sponsorState.statusCall?._reason)).toBe("Sponsor discussion is underway");
});

test("migration retains the database-enforced anti-spam and access controls", async ({ page }) => {
  const response = await page.request.get("/supabase/migrations/20261025000000_public_sponsorship.sql");
  expect(response.ok()).toBeTruthy();
  const sql = await response.text();
  expect(sql).toContain("pg_advisory_xact_lock");
  expect(sql).toContain("interval '15 minutes'");
  expect(sql).toContain("enable row level security");
  expect(sql).toContain("revoke update,insert,delete on public.sponsor_enquiries from authenticated");
  expect(sql).toContain("create or replace function public.sponsor_enquiry_set_status");
  expect(sql).toContain("'agreement_reached'");
  expect(sql).toContain("'account_setup'");
  expect(sql).toContain("'linked'");
  expect(sql).toContain("revoke all on public.sponsor_public_settings from public,anon,authenticated");
  expect(sql).toContain("sponsor_public_settings_updated");
  expect(sql).not.toContain("create or replace function private.valid_club_record_data");
});


test("Sponsor Lead can create and audit-log a sponsor account link through the existing RPC", async ({ page }) => {
  await page.route("**/private-nav.js*", route => route.abort());
  await page.route("https://esm.sh/@supabase/supabase-js@2", route => route.fulfill({
    status: 200,
    contentType: "application/javascript",
    body: `
      window.__linkState={links:[],calls:[]};
      const users=[{user_id:"sponsor-user-2",email:"sponsor@example.test",linked_sponsor_id:null}];
      const sponsors=[{id:"sponsor-record-1",name:"Approved Test Sponsor",details:"Public approved record",contact_person:"Test Contact",contact_email:"sponsor@example.test",contact_phone:"0700000000"}];
      export function createClient(){return {
        auth:{getSession:async()=>({data:{session:{user:{id:"lead-user-1"}}},error:null}),signOut:async()=>({error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
        rpc:async(name,args={})=>{
          window.__linkState.calls.push({name,args});
          if(name==="sponsor_lead_get_links") return {data:window.__linkState.links,error:null};
          if(name==="sponsor_lead_get_link_options") return {data:{sponsor_users:users,sponsors,profile_edits:[]},error:null};
          if(name==="sponsor_lead_set_user_link"){
            if(args._link){window.__linkState.links.push({id:"link-1",user_id:args._user_id,sponsor_record_id:args._sponsor_record_id,active:true,linked_at:"2026-10-25T10:00:00Z",reason:args._reason,email:"sponsor@example.test",sponsor_name:"Approved Test Sponsor"});users[0].linked_sponsor_id=args._sponsor_record_id;}
            else {window.__linkState.links.forEach(x=>{if(x.user_id===args._user_id)x.active=false;});users[0].linked_sponsor_id=null;}
            return {data:{ok:true,link_id:"link-1",active:args._link,sponsor_record_id:args._sponsor_record_id},error:null};
          }
          return {data:null,error:null};
        }
      }}
    `
  }));
  await page.goto("/app/sponsor-links.html");
  await expect(page.getByText("Sponsor links and profile drafts loaded.")).toBeVisible();
  await page.getByLabel("Sponsor user account").selectOption("sponsor-user-2");
  await page.getByLabel("Approved sponsor / partner record").selectOption("sponsor-record-1");
  await page.getByLabel("Reason for link, change or unlink").fill("Approved account-link integration test");
  await page.getByRole("button", { name: "Link / change sponsor" }).click();
  await expect(page.getByText("Sponsor account linked.")).toBeVisible();
  await expect(page.locator("#links")).toContainText("ACTIVE");
  await expect(page.locator("#links")).toContainText("Approved Test Sponsor");
  await expect.poll(() => page.evaluate(() => window.__linkState.calls.some(c => c.name==="sponsor_lead_set_user_link" && c.args._link===true && c.args._user_id==="sponsor-user-2" && c.args._sponsor_record_id==="sponsor-record-1"))).toBe(true);
});
