# Kept — iOS app

Native SwiftUI implementation of Kept. Written in a cloud dev container with no Xcode/macOS
available, so none of this has been compiled yet — open it in Xcode and fix whatever comes
up red; the architecture and business logic are complete, but Xcode's compiler is the first
real check this code gets.

## 1. Prerequisites

- A Mac with Xcode 15 or later.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple Developer Program membership ($99/year) — not needed to build and run in the
  Simulator, but required before running on a physical device or submitting to the App
  Store (see `docs/APP_STORE_GUIDE.md`).

## 2. Generate and open the Xcode project

The `.xcodeproj` itself isn't checked in (see `.gitignore`) — `project.yml` is the source of
truth, and XcodeGen turns it into a real project:

```sh
cd ios/Kept
xcodegen generate
open Kept.xcodeproj
```

Pick the **Kept** scheme and Run. On first launch you'll land on the Welcome screen (real
phone-based sign up/log in, no passwords). Until Supabase is configured, the app talks to
`MockBackendService` — tap Sign Up, enter any phone number, and when it asks for the code
use **`123456`** (shown on-screen too) instead of waiting for a real text. That lands you
in the one-time onboarding step, then the app, seeded with the same demo data as
`docs/kept.html` so it's fully click-through-able before Supabase exists.

## 3. Type faces

Fraunces, Inter, and IBM Plex Mono (all open-source, SIL Open Font License) are already
checked into `Kept/Resources/Fonts/` and wired into `project.yml`'s `UIAppFonts` list —
nothing to download. If you ever need to swap a weight, the file's *internal* PostScript
name is what `Font.custom(_:size:)` looks up, which isn't always the same as its filename
(e.g. Fraunces' italic file identifies itself as `Fraunces-MediumItalic`, not
`Fraunces-Italic`) — check with `fc-scan --format "%{postscriptname}\n" SomeFont.ttf` if a
newly added font silently falls back to the system font.

## 4. Set up Supabase (backend)

1. Create a project at https://supabase.com.
2. In the SQL editor, run `Supabase/schema.sql` — this creates every table and the
   row-level security policies that enforce "Kept is fully invisible" and "Open only
   exposes today's check-ins" server-side.
3. Project Settings → API → copy the Project URL and `anon` public key into
   `Kept/Services/SupabaseConfig.swift`. The anon key is meant to be public/client-side;
   RLS is what actually protects data.
4. Deploy the account-deletion Edge Function (needs the Supabase CLI:
   `brew install supabase/tap/supabase`):
   ```sh
   supabase functions deploy delete-account --project-ref YOUR-PROJECT-REF
   ```
5. Storage: create a public bucket named `avatars` (Storage → New bucket) for profile
   photos.
6. Phone auth needs an SMS provider — Authentication → Providers → Phone → enable it and
   connect Twilio (or MessageBird/Vonage). This costs a small amount per text and requires
   its own account; there's no way around a paid SMS provider for real phone verification.
   Until this is set up, real devices won't receive codes — keep testing against
   `MockBackendService`'s fixed code instead.

Once `SupabaseConfig.isConfigured` is true, `KeptApp` automatically switches from
`MockBackendService` to `SupabaseBackendService` — no other code changes needed.

`fetchCircleMembers` and `fetchCircleFeed` currently return empty arrays in
`SupabaseBackendService` — wiring up real multi-user Circle data (friends' profiles +
today's open check-ins) is the next piece of backend work once you have more than one real
account to test against; the RLS policy that will drive it (`check_ins_circle_select_open_today`)
is already in `schema.sql`.

## 5. Test payments locally (StoreKit)

`StoreKit/Kept.storekit` is a local test configuration with one product,
`com.kept.app.keptplus.monthly`, priced at $8.99/mo — already wired into the scheme in
`project.yml`. In the Simulator or on a device, open the Paywall tab and tap Continue; you'll
get Apple's real (but sandboxed) purchase sheet with no actual charge. If Xcode doesn't pick
up the StoreKit config automatically: **Product → Scheme → Edit Scheme → Run → Options →
StoreKit Configuration** and select `StoreKit/Kept.storekit`.

This local product ID is independent from whatever you'll create in App Store Connect —
see `docs/APP_STORE_GUIDE.md` for wiring up the real one before submission.

## 6. Test invite links

Invites work via a custom URL scheme (`kept://invite?inviter=...&name=...`), registered in
`project.yml` and handled by `AppModel.handleIncomingURL`. To test the accept side without a
second physical device: run the app in two Simulators (or two accounts on one), grab the link
from Add to Circle → Share/Copy on one, then open a terminal and run:

```
xcrun simctl openurl booted "kept://invite?inviter=<uuid-from-the-link>&name=Test"
```

on the other Simulator — that triggers the same `onOpenURL` path a real tap would, and the
Accept/Decline sheet should appear. Note this is a custom scheme, not a Universal Link: it
only works once Kept is already installed. Falling back to the App Store for someone who
doesn't have it yet needs a real hosted domain with an `apple-app-site-association` file —
worth adding once there's a website to host it on, not required to ship v1.

## 7. Project layout

```
Kept/App/              App entry point, AppModel (central state + business logic), tab bar
Kept/DesignSystem/      Colors, typography, shared button/card styles
Kept/Models/            Habit, UserProfile, CircleMember, NotificationSettings, Plan, ...
Kept/Services/          BackendService protocol + Supabase/Mock implementations,
                        StoreKitManager, NotificationScheduler
Kept/Views/             One folder per screen from kept.html
Supabase/schema.sql     Tables + RLS policies
Supabase/functions/     Edge Functions (account deletion)
StoreKit/Kept.storekit  Local subscription test configuration
```
