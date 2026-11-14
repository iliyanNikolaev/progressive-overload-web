-- Allow each authenticated user to delete only their own workouts.
-- Child exercises and sets are removed through the existing ON DELETE CASCADE foreign keys.
drop policy if exists "Users delete active workouts" on public.workouts;
drop policy if exists "Users delete their workouts" on public.workouts;
create policy "Users delete their workouts" on public.workouts
  for delete to authenticated
  using (user_id = (select auth.uid()));
