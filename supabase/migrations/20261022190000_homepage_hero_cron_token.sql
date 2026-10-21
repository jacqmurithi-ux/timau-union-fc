-- Secure scheduled expiry with a dedicated Vault token, not the service-role key.
-- The Edge Function is deployed with gateway JWT verification disabled and validates
-- this token through a service-role-only RPC before doing any cleanup.
begin;

do $secrets$
begin
  if to_regclass('vault.decrypted_secrets') is null then
    raise exception 'Supabase Vault is required for scheduled homepage hero expiry';
  end if;
  if not exists(select 1 from vault.decrypted_secrets where name='project_url') then
    perform vault.create_secret('https://owvvimydkjsjlrmnzvdi.supabase.co','project_url');
  end if;
  if not exists(select 1 from vault.decrypted_secrets where name='homepage_hero_cron_token') then
    perform vault.create_secret(
      replace(gen_random_uuid()::text||gen_random_uuid()::text||gen_random_uuid()::text,'-',''),
      'homepage_hero_cron_token'
    );
  end if;
end
$secrets$;

create or replace function public.homepage_hero_cron_authorized(_token text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select _token is not null
    and length(_token) >= 64
    and _token = (
      select decrypted_secret
      from vault.decrypted_secrets
      where name='homepage_hero_cron_token'
      limit 1
    )
$$;
revoke all on function public.homepage_hero_cron_authorized(text) from public, anon, authenticated;
grant execute on function public.homepage_hero_cron_authorized(text) to service_role;

do $schedule$
declare v_job bigint;
begin
  select jobid into v_job from cron.job where jobname='expire-homepage-hero-slides';
  if v_job is not null then perform cron.unschedule(v_job); end if;
  perform cron.schedule(
    'expire-homepage-hero-slides','*/15 * * * *',
    $command$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name='project_url' limit 1) || '/functions/v1/expire-homepage-hero',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='homepage_hero_cron_token' limit 1)
        ),
        body := '{}'::jsonb
      );
    $command$
  );
end
$schedule$;

commit;
