-- Allow the public, invoker-security news list to return the optional poster path.
grant select (poster_path) on public.club_news to anon, authenticated;