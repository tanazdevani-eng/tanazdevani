-- Kept — Supabase schema and row-level security policies.
-- Run this in the Supabase SQL editor (or via `supabase db push`) on a fresh project.
-- See ios/Kept/README.md for how to plug the resulting project URL + anon key into the app.

create extension if not exists "pgcrypto";

-- ---------- Profiles ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  handle text unique not null,
  bio text not null default '',
  avatar_url text,
  default_visibility text not null default 'open' check (default_visibility in ('open','kept')),
  day_reset_hour int not null default 0,
  remind_for_all_habits boolean not null default true,
  all_habits_reminder_time time not null default '07:00',
  customize_per_habit boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- Habits ----------
create table public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  visibility text not null check (visibility in ('open','kept')),
  goal_duration_days int,
  reminder_time time,
  reminder_on boolean not null default true,
  created_at timestamptz not null default now()
);

-- Kept+ only: restricts an Open habit to a subset of the owner's Circle instead of
-- everyone (e.g. sharing an accountability habit with just one friend). No rows for a
-- given habit_id means the default "everyone in Circle" behavior — see the check_ins
-- policy below, which is where this actually gets enforced.
create table public.habit_audience (
  habit_id uuid not null references public.habits(id) on delete cascade,
  member_id uuid not null references auth.users(id) on delete cascade,
  primary key (habit_id, member_id)
);

-- ---------- Check-ins ----------
create table public.check_ins (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  logical_day date not null,
  note text,
  -- 'missed' is a "down day" post: logged on purpose (couldn't get to it today), visible
  -- to Circle exactly like a 'done' post so people can show up for you either way, but
  -- never counted toward a streak — see habit_streak_count below.
  status text not null default 'done' check (status in ('done', 'missed')),
  created_at timestamptz not null default now(),
  unique (habit_id, logical_day)
);

-- ---------- Circle (directed edge: owner has member in their circle) ----------
create table public.circle_members (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  member_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (owner_id, member_id)
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_contact text not null,
  invitee_name text not null,
  status text not null default 'pending' check (status in ('pending','accepted','cancelled')),
  created_at timestamptz not null default now()
);

-- ---------- Reactions & nudges ----------
create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  check_in_id uuid not null references public.check_ins(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (check_in_id, user_id)
);

create table public.nudges (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users(id) on delete cascade,
  to_user_id uuid not null references auth.users(id) on delete cascade,
  logical_day date not null,
  created_at timestamptz not null default now(),
  unique (from_user_id, to_user_id, logical_day)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  check_in_id uuid not null references public.check_ins(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);

-- ---------- Content moderation (App Store Guideline 1.2 / UGC) ----------
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  check_in_id uuid references public.check_ins(id) on delete set null,
  reason text not null,
  created_at timestamptz not null default now()
);

create table public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_id)
);

-- One row per device that's granted notification permission. A user can have several
-- (old phone + new phone, etc.) — all get pushed to. Read/write is owner-only from the
-- client; the notify-invite-accepted Edge Function reads across users with the service
-- role key, same pattern as delete-account.
create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_token text not null,
  created_at timestamptz not null default now(),
  unique (user_id, device_token)
);

-- ---------- Row level security ----------
alter table public.profiles enable row level security;
alter table public.habits enable row level security;
alter table public.check_ins enable row level security;
alter table public.habit_audience enable row level security;
alter table public.circle_members enable row level security;
alter table public.invites enable row level security;
alter table public.reactions enable row level security;
alter table public.nudges enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.push_tokens enable row level security;

-- Profiles: readable by yourself and anyone who has you in their circle; writable by owner.
create policy "profiles_select_self_or_circle" on public.profiles
  for select using (
    id = auth.uid()
    or id in (select member_id from public.circle_members where owner_id = auth.uid())
  );
create policy "profiles_insert_self" on public.profiles
  for insert with check (id = auth.uid());
create policy "profiles_update_self" on public.profiles
  for update using (id = auth.uid());

-- Habits: only the owner can read/write. Friends never query this table directly —
-- Kept habits (including their name) must never leak, so visibility to friends is
-- expressed only through the check_ins policy below.
create policy "habits_owner_all" on public.habits
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- The Circle feed needs to show *which* habit a post is about, not just its note and
-- streak — this mirrors check_ins_circle_select_open_today's exact conditions (Open,
-- checked in today, audience-visible, not blocked) so a habit's name is only ever
-- readable by a circle member at the exact moment its check-in is already visible to
-- them, never more broadly.
create policy "habits_circle_select_if_checkin_visible_today" on public.habits
  for select using (
    visibility = 'open'
    and exists (
      select 1 from public.check_ins c
      where c.habit_id = habits.id
        and c.logical_day = (now() at time zone 'utc')::date
    )
    and exists (
      select 1 from public.circle_members cm
      where cm.owner_id = auth.uid() and cm.member_id = habits.user_id
    )
    and public.habit_visible_to(habits.id, auth.uid())
    and not exists (
      select 1 from public.blocks b where b.blocker_id = habits.user_id and b.blocked_id = auth.uid()
    )
  );

-- Check-ins: owner has full access. Circle members can SELECT only today's check-ins
-- on habits currently marked Open — this single policy is what enforces "Kept is fully
-- invisible" and "switching to Open only exposes future check-ins," server-side, with
-- no client trust required.
create policy "check_ins_owner_all" on public.check_ins
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Runs with elevated privileges specifically so it can check whether ANY audience
-- restriction rows exist for a habit without RLS on habit_audience hiding rows the
-- viewer isn't personally part of — without this, "not exists" would look true (no
-- restriction) from a restricted-out viewer's perspective, since they can't see the
-- rows that would prove otherwise. Only ever answers a yes/no, never returns row data.
create or replace function public.habit_visible_to(p_habit_id uuid, p_viewer uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select
    not exists (select 1 from public.habit_audience where habit_id = p_habit_id)
    or exists (select 1 from public.habit_audience where habit_id = p_habit_id and member_id = p_viewer)
$$;

-- Same reasoning as habit_visible_to(): a circle member's own view of check_ins is
-- deliberately restricted to *today* only (see the policy below), so the client can never
-- compute a friend's streak from raw rows the way it computes its own. This answers just
-- the aggregate number, mirroring the Swift DayCalendar.consecutiveStreak logic (counts
-- back from today, or yesterday if today isn't checked in yet, so a streak doesn't
-- visually zero out before the day's actual cutoff has passed).
create or replace function public.habit_streak_count(p_habit_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  streak int := 0;
  cursor_day date := (now() at time zone 'utc')::date;
begin
  if not exists (select 1 from public.check_ins where habit_id = p_habit_id and logical_day = cursor_day and status = 'done') then
    cursor_day := cursor_day - 1;
  end if;

  loop
    exit when not exists (select 1 from public.check_ins where habit_id = p_habit_id and logical_day = cursor_day and status = 'done');
    streak := streak + 1;
    cursor_day := cursor_day - 1;
  end loop;

  return streak;
end;
$$;

create policy "check_ins_circle_select_open_today" on public.check_ins
  for select using (
    logical_day = (now() at time zone 'utc')::date
    and exists (
      select 1 from public.habits h
      where h.id = check_ins.habit_id and h.visibility = 'open'
    )
    and exists (
      select 1 from public.circle_members cm
      where cm.owner_id = auth.uid() and cm.member_id = check_ins.user_id
    )
    and public.habit_visible_to(check_ins.habit_id, auth.uid())
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = check_ins.user_id and b.blocked_id = auth.uid()
    )
  );

-- Habit audience: only the habit's owner can read/write their own restriction list — no
-- one else needs direct table access, they only benefit from habit_visible_to() above.
create policy "habit_audience_owner_all" on public.habit_audience
  for all using (
    exists (select 1 from public.habits h where h.id = habit_audience.habit_id and h.user_id = auth.uid())
  )
  with check (
    exists (select 1 from public.habits h where h.id = habit_audience.habit_id and h.user_id = auth.uid())
  );

-- Circle Manage screen shows how many of each friend's habits are visible to you — the
-- habits table is owner-only (habits_owner_all), so this is the only way to get that
-- count without letting a circle member query someone else's habits table directly,
-- which would leak Kept habit names/existence.
create or replace function public.circle_open_habit_counts(p_owner uuid)
returns table (member_id uuid, open_habit_count bigint)
language sql
security definer
set search_path = public
as $$
  select cm.member_id, count(h.id)
  from public.circle_members cm
  join public.habits h on h.user_id = cm.member_id and h.visibility = 'open'
  where cm.owner_id = p_owner
    and public.habit_visible_to(h.id, p_owner)
    and not exists (
      select 1 from public.blocks b where b.blocker_id = h.user_id and b.blocked_id = p_owner
    )
  group by cm.member_id
$$;

create policy "circle_members_owner_select" on public.circle_members
  for select using (owner_id = auth.uid());
create policy "circle_members_owner_write" on public.circle_members
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "invites_owner_all" on public.invites
  for all using (inviter_id = auth.uid()) with check (inviter_id = auth.uid());

create policy "reactions_select_if_checkin_visible" on public.reactions
  for select using (exists (select 1 from public.check_ins c where c.id = reactions.check_in_id));
create policy "reactions_insert_self" on public.reactions
  for insert with check (user_id = auth.uid());
create policy "reactions_owner_update" on public.reactions
  for update using (user_id = auth.uid());
create policy "reactions_owner_delete" on public.reactions
  for delete using (user_id = auth.uid());

create policy "nudges_sender_all" on public.nudges
  for all using (from_user_id = auth.uid()) with check (from_user_id = auth.uid());
create policy "nudges_recipient_select" on public.nudges
  for select using (to_user_id = auth.uid());

-- Comments follow the same visibility rule as reactions: anyone who can see the
-- underlying check-in can comment on it and read others' comments there.
create policy "comments_select_if_checkin_visible" on public.comments
  for select using (exists (select 1 from public.check_ins c where c.id = comments.check_in_id));
create policy "comments_insert_self" on public.comments
  for insert with check (user_id = auth.uid());
create policy "comments_owner_delete" on public.comments
  for delete using (user_id = auth.uid());

-- Reports/blocks: required for App Store Review Guideline 1.2 (user-generated content).
create policy "reports_insert_self" on public.reports
  for insert with check (reporter_id = auth.uid());
create policy "reports_select_self" on public.reports
  for select using (reporter_id = auth.uid());

create policy "blocks_owner_all" on public.blocks
  for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy "push_tokens_owner_all" on public.push_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- Notes ----------
-- Account deletion (auth.users row + cascades) requires the service role key, which must
-- never ship in the client. Deploy a Supabase Edge Function that runs with the service
-- role and calls supabase.auth.admin.deleteUser(userId) — see Supabase/functions/delete-account.
-- Kept+ entitlement is decided on-device via StoreKit 2's Transaction.currentEntitlements
-- (Apple's recommended lightweight approach — see Kept/Services/StoreKitManager.swift), so
-- there is no subscriptions table here. If you later want server-side enforcement too
-- (e.g. to gate Circle feed size for non-subscribers), add one and populate it from App
-- Store Server Notifications.
