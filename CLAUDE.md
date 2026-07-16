# Kept — Project Brief for Claude Code

## What this is

**Kept** is an iOS habit tracker where every habit has a visibility setting: **Open** (visible to your Circle, a small group of friends who can react and nudge you) or **Kept** (fully private, invisible to everyone). The core idea: it's Hinge for habits. Same card-stack, editorial, warm-but-restrained aesthetic, but the "match" mechanic is replaced with a visibility toggle. Color itself carries meaning: orange means shown to others, dark purple means private, so a glance at someone's habit list tells you what's shared before you read a word.

A full interactive HTML/CSS/JS mockup of this app is attached in this project folder as **`docs/kept.html`**. Open it in a browser to see every screen, exact copy, exact colors, and working click-through interaction logic. **Treat `docs/kept.html` as the source of truth for design and UX** — colors, spacing, typography, copy, and interaction states should all be ported faithfully into the native app rather than reinvented. Where this document and the mockup ever conflict, the mockup wins on visual/UX details; this document wins on data model, business logic, and things the mockup fakes for demo purposes (e.g. it doesn't have a real backend).

The native SwiftUI implementation lives in **`ios/Kept`**. See `ios/Kept/README.md` for how to open and build it.

## Target platform

Native iOS app, built for the App Store. SwiftUI, single-platform (iOS), standard UI patterns (lists, forms, tab navigation, modals). Requires a Mac with Xcode to build.

## Design system

- **Palette**: warm ivory background (`#FBF6F0`), near-black ink for text (`#211C24`), muted warm grey for secondary text (`#6B6470`). Two accent colors carry all meaning: **orange** (`#FF6A2C`, deep variant `#E6551A`, soft tint `#FFE3D0`) for "Open," **dark purple** (`#3E1969`, deep variant `#2A1150`, soft tint `#E7DEF0`) for "Kept." No other accent colors are used, this restraint is intentional.
- **Typography**: display/headline face is **Fraunces** (serif, used italic for the wordmark and habit names, gives editorial warmth). Body/UI text is **Inter**. Data/numeric/label text (streak counts, timestamps, mono-style tags) uses **IBM Plex Mono**.
- **Cards**: habit cards on Home use a soft gradient wash (white to a tinted color at ~130% angle) matching their visibility, not a flat fill, plus a colored border.
- **No decorative icons.** Habit cards, the check-in screen, and Notifications rows all rely on typography and the orange/purple color system alone, no emoji or icon library. Do not add an icon picker unless explicitly asked. If icons are ever reintroduced, they should be a proper searchable icon library opened from a single button, not an inline grid.
- Buttons are full-width pills with heavy rounding (100px radius). Cards use large border-radius (~20-26px). This is a soft, warm, rounded aesthetic throughout, not sharp/angular.

## Core screens (all present in kept.html)

1. **Home** — list of the user's habit cards. Each card shows: habit name, a subtitle line that ONLY appears when there's something to say (checked in today, and/or a duration goal like "Day 1 of 30") — never repeats the Open/Kept status in words, since the pill already shows it. Each card has an Open/Kept pill (tap to toggle visibility instantly), a streak-dot progress row, an edit trigger ("⋯"), and a "Check in today" button.
2. **Check-in flow** — tapping "Check in today" IS the check-in (no separate confirm step). Opens a dedicated screen already marked done, with an optional note field and a reminder of what will happen ("this will post to your Circle" vs "this stays private"). Tapping the same button again on Home (once already checked in) instantly undoes it, no extra screen.
3. **Circle** — social feed showing only what friends (and the user) have marked Open. Each post can get a reaction (tap opens a real emoji picker: ❤️🔥👏💪🙌, not a fixed single reaction) or a Nudge — **but only show Nudge on people who have NOT checked in today**; nudging someone who already checked in doesn't make sense. The user's own posts show a small "✕" to pull the post back (which also un-checks the habit on Home). A note at the bottom reinforces that Kept habits are fully invisible here, not just hidden behind a lock icon.
4. **Add Habit / Edit Habit** — name, visibility (Open/Kept), and duration (Ongoing, or 7/21/30/90 days, or Custom with a number input). Edit also has a Delete option with a confirm step. Free tier shows a soft nudge about locks when picking Kept, but doesn't hard-block it, only the total habit count is hard-gated.
5. **Add to Circle** — invite via a shareable link (with copy feedback), search field, and a contacts list with per-person Invite state (Invite → Pending). Successfully inviting someone navigates to a dedicated **Invite Sent** confirmation screen (checkmark, preview of the invite message) rather than just toasting.
6. **Manage Circle** — separate from the Circle feed. Shows current members with a Remove option and pending invites with Cancel. Removing a real member decrements the circle-size count everywhere it's displayed (Profile stat, settings row, this screen's header). Canceling a pending invite does NOT decrement the count (they were never actually a member).
7. **Profile** — avatar (tap to open Edit Profile), name, handle, bio, a Kept+ member chip (only shown if subscribed), and three live stats: day streak, habits kept (count of actual habit cards, updates on add/delete), people in circle. Settings grouped into Account (Edit profile, Notifications, Default habit privacy toggle), Circle (Invite friends, Manage circle), Billing (Manage subscription, Log out), and a final Account section with just **Delete account** (no separate "deactivate" option — keep it simple, one clear destructive action, and the confirm copy should note the person is welcome to sign up again later with the same email).
8. **Edit Profile** — real screen: Name, Username, Bio fields, pre-filled from current profile, writes back on save. Photo tap opens a picker (native photo library access in the real app).
9. **Notifications** — a global "remind me for all habits" toggle + time, a "customize per habit" toggle that reveals individual reminder rows per habit (auto-synced: new habits get a row, deleted habits lose theirs, renamed habits update in place), and a separate **day-reset time** setting (when streaks roll over, important for night-shift/late-checkin users, default midnight).
10. **Paywall (Kept+)** — Free ($0: 3 habits, 1 private lock, Circle access) vs **Kept+ ($8.99/mo**: unlimited habits, unlimited locks, multiple circles, streak insights). If the user is already subscribed, this screen must reflect that: show "You're currently on Kept+," disable the acquisition flow, and point to iPhone Settings for managing/canceling — **do not build an in-app cancel/downgrade flow**, Apple does not allow that for auto-renewable subscriptions.

## Data model (habits)

Each habit needs: id, name, visibility (open/kept), streak count, days-since-start, optional goal duration in days (or null for ongoing), whether it was checked in today, and its check-in history (for streak calculation and any future analytics). Visibility changes must cascade: switching a habit to Kept must immediately remove any of today's Circle post for it (never leave a stale public post for something now marked private). Switching to Open should NOT retroactively expose past private check-ins, only future check-ins post.

## Monetization — how this actually gets built

The mockup's paywall is a visual reference only; it cannot process real payments (it's a static HTML file). For the real app:

- **Must use StoreKit 2** (Apple's in-app purchase framework) for the Kept+ auto-renewable subscription. Apple requires this for all digital subscriptions, custom payment forms are not allowed and will get the app rejected.
- Set up the subscription product in **App Store Connect** (requires an active Apple Developer Program membership, $99/year).
- Money flows: Apple charges the customer's Apple ID payment method → Apple takes its commission (30%, or 15% under the Small Business Program for developers under $1M/year revenue) → remainder pays out to the developer's bank account on file in App Store Connect's Agreements, Tax, and Banking section, roughly monthly.
- Free tier limits to enforce server-side or at minimum locally with receipt validation: 3 active habits, 1 "Kept" (private) habit lock. Kept+ removes both caps.
- No custom cancel/downgrade UI in the app. Apple handles all of that through the user's Settings.
- Kept+ is priced at **$8.99/month**.

## Backend

Supabase (Postgres + Auth + Realtime + Storage), chosen as the first implementation decision: relational schema maps cleanly onto the Circle/visibility rules via row-level security, and `supabase-swift` has a solid native client. See `ios/Kept/Supabase/schema.sql` for the schema and RLS policies.

## Things intentionally simplified in the mockup, needs real thought in the build

- Real photo upload (camera roll + crop) behind the profile photo edit button, plus basic content moderation on uploaded photos before anything is shown to others.
- Push notification delivery for the reminder system (the mockup's Notifications screen is UI-only, no real scheduling).
- Contact-list access and SMS/invite-link sharing via the native iOS share sheet, rather than the mockup's fake contact rows.
- Circle/friend acceptance flow (the mockup only shows the "inviter" side; someone has to actually accept on their end).
- App Store Review Guideline 1.2 (User-Generated Content) compliance: since Circle is social with user posts, the app needs a report/block mechanism and a way to filter objectionable content before this can pass review.

## Brand quick reference

- Name: **Kept**
- Tagline energy: "some habits you keep, some you keep to yourself"
- Tone: warm, confident, a little editorial, never cutesy or overly gamified. Avoid exclamation points and hype language in UI copy.
