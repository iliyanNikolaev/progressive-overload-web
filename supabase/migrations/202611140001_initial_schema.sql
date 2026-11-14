-- Progressive Overload: personal workout diary
-- Safe to run on a new Supabase project. No existing data is dropped.
create extension if not exists pgcrypto;

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  created_at timestamptz not null default now()
);
create unique index if not exists exercises_user_name_unique on public.exercises(user_id, lower(name));
create index if not exists exercises_user_created_idx on public.exercises(user_id, created_at desc);

create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','completed')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  check ((status = 'active' and completed_at is null) or (status = 'completed' and completed_at is not null))
);
create unique index if not exists workouts_one_active_per_user on public.workouts(user_id) where status = 'active';
create index if not exists workouts_user_completed_idx on public.workouts(user_id, completed_at desc) where status = 'completed';

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts(id) on delete cascade,
  exercise_id uuid references public.exercises(id) on delete set null,
  exercise_name text not null check (char_length(trim(exercise_name)) between 1 and 100),
  position integer not null default 0 check (position >= 0),
  created_at timestamptz not null default now(),
  unique (workout_id, position)
);
create index if not exists workout_exercises_exercise_idx on public.workout_exercises(exercise_id);

create table if not exists public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_exercise_id uuid not null references public.workout_exercises(id) on delete cascade,
  weight numeric(8,2) check (weight is null or weight >= 0),
  reps integer check (reps is null or reps > 0),
  position integer not null default 0 check (position >= 0),
  created_at timestamptz not null default now(),
  unique (workout_exercise_id, position)
);
create index if not exists workout_sets_parent_idx on public.workout_sets(workout_exercise_id, position);

alter table public.exercises enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_sets enable row level security;

drop policy if exists "Users manage their exercises" on public.exercises;
create policy "Users manage their exercises" on public.exercises for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "Users manage their workouts" on public.workouts;
drop policy if exists "Users read their workouts" on public.workouts;
drop policy if exists "Users create workouts" on public.workouts;
drop policy if exists "Users update active workouts" on public.workouts;
drop policy if exists "Users delete active workouts" on public.workouts;
create policy "Users read their workouts" on public.workouts for select to authenticated using (user_id = (select auth.uid()));
create policy "Users create workouts" on public.workouts for insert to authenticated with check (user_id = (select auth.uid()) and status = 'active' and completed_at is null);
create policy "Users update active workouts" on public.workouts for update to authenticated
  using (user_id = (select auth.uid()) and status = 'active') with check (user_id = (select auth.uid()));
create policy "Users delete active workouts" on public.workouts for delete to authenticated using (user_id = (select auth.uid()) and status = 'active');

drop policy if exists "Users manage exercises in their workouts" on public.workout_exercises;
drop policy if exists "Users read exercises in their workouts" on public.workout_exercises;
drop policy if exists "Users write exercises in active workouts" on public.workout_exercises;
create policy "Users read exercises in their workouts" on public.workout_exercises for select to authenticated
  using (exists (select 1 from public.workouts w where w.id = workout_id and w.user_id = (select auth.uid())));
create policy "Users write exercises in active workouts" on public.workout_exercises for all to authenticated
  using (exists (select 1 from public.workouts w where w.id = workout_id and w.user_id = (select auth.uid()) and w.status = 'active'))
  with check (
    exists (select 1 from public.workouts w where w.id = workout_id and w.user_id = (select auth.uid()) and w.status = 'active')
    and (exercise_id is null or exists (select 1 from public.exercises e where e.id = exercise_id and e.user_id = (select auth.uid())))
  );

drop policy if exists "Users manage sets in their workouts" on public.workout_sets;
drop policy if exists "Users read sets in their workouts" on public.workout_sets;
drop policy if exists "Users write sets in active workouts" on public.workout_sets;
create policy "Users read sets in their workouts" on public.workout_sets for select to authenticated
  using (exists (
    select 1 from public.workout_exercises we join public.workouts w on w.id = we.workout_id
    where we.id = workout_exercise_id and w.user_id = (select auth.uid())
  ));
create policy "Users write sets in active workouts" on public.workout_sets for all to authenticated
  using (exists (
    select 1 from public.workout_exercises we join public.workouts w on w.id = we.workout_id
    where we.id = workout_exercise_id and w.user_id = (select auth.uid()) and w.status = 'active'
  ))
  with check (exists (
    select 1 from public.workout_exercises we join public.workouts w on w.id = we.workout_id
    where we.id = workout_exercise_id and w.user_id = (select auth.uid()) and w.status = 'active'
  ));

grant select, insert, update, delete on public.exercises, public.workouts, public.workout_exercises, public.workout_sets to authenticated;

-- Validate that the referenced exercise, if set, belongs to the workout owner.
create or replace function public.validate_workout_exercise_owner()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.exercise_id is not null and not exists (
    select 1 from public.exercises e join public.workouts w on w.id = new.workout_id
    where e.id = new.exercise_id and e.user_id = w.user_id
  ) then
    raise exception 'Exercise must belong to the workout owner';
  end if;
  return new;
end;
$$;
drop trigger if exists workout_exercise_owner_check on public.workout_exercises;
create trigger workout_exercise_owner_check before insert or update of exercise_id, workout_id
  on public.workout_exercises for each row execute function public.validate_workout_exercise_owner();

