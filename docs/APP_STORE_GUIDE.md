# Shipping Kept to the App Store — step by step

This assumes the app builds and runs from `ios/Kept` (see its README) and you're working
on a Mac with Xcode. Steps are sequential; do them roughly in this order.

## 1. Apple Developer Program enrollment

1. Go to https://developer.apple.com/programs/enroll/ and enroll as an **Individual** (or
   **Organization** if you're shipping under a company/legal entity — organizations need a
   D-U-N-S number, which can take a few days to a couple of weeks to obtain if you don't
   already have one, so start this first if you're going the org route).
2. Pay the $99/year fee. Approval is usually near-instant for individuals.
3. Once enrolled, sign in at https://appstoreconnect.apple.com — this is where everything
   else in this guide happens.

## 2. Register the App ID and set up code signing

1. In Xcode, open `ios/Kept/Kept.xcodeproj` (after `xcodegen generate`).
2. Select the **Kept** target → **Signing & Capabilities**.
3. Check "Automatically manage signing" and select your Team (your Apple ID, once
   enrolled, shows up here). Xcode will register the `com.kept.app` bundle identifier and
   provisioning profile for you the first time you build to a device.
4. If you want a different bundle ID (e.g. your own reverse-DNS), change
   `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Kept/project.yml`, then re-run `xcodegen generate`.

## 3. Create the app record in App Store Connect

1. App Store Connect → **Apps** → **+** → **New App**.
2. Platform: iOS. Name: **Kept** (or a variant if taken — App Store names are globally
   unique; have 2-3 backups ready like "Kept Habits" or "Kept — Habit Tracker").
3. Primary language: English (U.S.). Bundle ID: pick `com.kept.app` from the dropdown
   (populated once you've built once from Xcode with that ID). SKU: any internal string,
   e.g. `kept-ios-001`.

## 4. Set up the Kept+ subscriptions ($8.99/month, $79.99/year)

1. In your app's page → **Monetization** → **Subscriptions**.
2. Create a **Subscription Group** named `Kept Membership` (matches
   `ios/Kept/StoreKit/Kept.storekit`'s local group — the names don't have to match but it
   keeps things easy to reason about). Both plans below go in this *same* group — that's
   what makes them mutually exclusive (a subscriber is on one or the other, never both) and
   lets someone switch between them from iPhone Settings without double-billing.
3. Add the monthly subscription:
   - Reference name: `Kept+ Monthly`
   - Product ID: `com.kept.app.keptplus.monthly` — **must match**
     `StoreKitManager.monthlyProductID` in `ios/Kept/Kept/Services/StoreKitManager.swift`
     exactly, or the app won't find the product.
   - Subscription duration: 1 month. Price: **$8.99 USD/month**.
4. Add the yearly subscription in the same group:
   - Reference name: `Kept+ Yearly`
   - Product ID: `com.kept.app.keptplus.yearly` — must match `StoreKitManager.yearlyProductID`.
   - Subscription duration: 1 year. Price: **$79.99 USD/year** (~$6.67/mo, about 26% off
     paying monthly — pick the price tier closest to $79.99 in the price schedule).
   - Give it a **higher rank** than monthly within the group (App Store Connect lets you
     order subscriptions in a group) so it's treated as the "upgrade" tier — matters for how
     Apple's own upgrade/downgrade prompts behave if someone switches plans.
5. For both: Apple auto-generates equivalent prices for every other storefront/currency;
   review territory pricing if you want manual control instead of the default. Localization
   (English, U.S.) description should match the paywall copy ("Unlimited habits, unlimited
   private locks, share with just a few people, streak insights."). App Store subscription
   image is optional but recommended for the system subscription management UI — a simple
   square graphic with the Kept wordmark works for both.
6. Submit both subscriptions' review information (screenshot of the paywall + review
   notes) — subscriptions are reviewed alongside your first app submission, not separately,
   for a brand-new app.
5. **Do not** build any in-app cancel/downgrade UI — `PaywallView` already only ever shows
   "Manage in iPhone Settings" (via `manageSubscriptionsSheet`) once subscribed. Apple
   requires all cancellation to go through the system, not a custom flow.

## 5. Banking, tax, and agreements

1. App Store Connect → **Agreements, Tax, and Banking**.
2. Accept the **Paid Applications Agreement** (required before any paid product,
   including subscriptions, can go live).
3. Fill in **Tax** forms (a W-9 for US individuals, W-8BEN for non-US) and **Banking**
   (routing/account number for payouts).
4. Payouts land roughly monthly, net of Apple's commission: 30% standard, or 15% if
   you're in the **Small Business Program** (enroll separately, free, for developers
   under $1M/year revenue — worth doing before your first sale if you qualify, since it's
   not retroactive within a calendar year in all cases).

## 6. App Store listing content

You'll need, in App Store Connect → your app → **App Store** tab:

- **Screenshots**: at minimum, 6.7" (iPhone 15 Pro Max class) and 6.5" or 5.5" as
  fallback sizes Apple still asks for on some accounts. Capture from the Simulator
  (Cmd+S in the Simulator app saves a PNG at device resolution) — grab Home, Circle, Add
  Habit, and Paywall at minimum.
- **App description, keywords, promotional text, support URL, marketing URL** (support
  URL is required — even a simple page or a `mailto:` link works to start).
- **App icon**: 1024×1024 PNG, no alpha channel, no rounded corners (Apple applies the
  mask). Replace the placeholder in `Kept/Resources/Assets.xcassets/AppIcon.appiconset`.
- **Age rating** questionnaire (App Store Connect → App Information) — Kept has no
  age-restricted content, so this should land at the lowest tier, but you do need to
  answer the questions (user-generated content and social features push the effective
  minimum age up slightly on some rating systems — answer honestly, Circle is UGC).

## 7. Privacy details (App Privacy / "nutrition label")

App Store Connect → your app → **App Privacy**. Answer based on what Kept actually
collects once Supabase is wired up:

- **Account data** (email) — linked to identity, used for app functionality.
- **User content** (habit names, notes, photos) — linked to identity, used for app
  functionality; disclose that some of it (Open habits, check-in notes) is shared with
  other users via the Circle feature.
- **Identifiers** — if you add any analytics/crash reporting later, disclose that too.
- Publish a **Privacy Policy URL** — required for any app collecting data, which Kept
  does. A simple hosted markdown-to-page or a one-page site is enough; it must actually
  describe what's in this section.

## 8. Guideline 1.2 (User-Generated Content) — required before this can pass review

Circle is social with user-authored posts (check-in notes, photos), which puts Kept
squarely under Guideline 1.2. These are now built:

- **Report** control on every Circle post — tap "⋯" on a friend's post in
  `FriendPostCard`, pick a reason, and it inserts a row into the `reports` table.
- **Block** control per-user — same "⋯" menu, "Block" inserts into the `blocks` table;
  the RLS policy on `check_ins` already excludes a blocker's posts from a blocked user's
  feed going forward.
- A way to **contact you** about objectionable content (the support URL from step 6
  satisfies this if it's monitored).
- State in your App Review notes (step 10) that reporting/blocking exists and where a
  reviewer can find it, since it's easy to miss in a quick review pass.

## 9. TestFlight

1. Archive the app in Xcode (**Product → Archive**) once signing is set up, then
   **Distribute App → App Store Connect → Upload**.
2. In App Store Connect → **TestFlight**, the build appears after processing (10-30 min
   typically). Fill in "What to Test" and submit for **Beta App Review** if you want
   external (non-team) testers — internal testers (your own team, up to 100 people) don't
   need that review and get access immediately.
3. Actually install it via TestFlight on a real device and run through: add/edit/delete a
   habit, toggle visibility, check in and undo, invite flow, the paywall purchase using a
   **Sandbox Apple ID** (App Store Connect → Users and Access → Sandbox Testers — sign
   into this account in Settings → App Store → Sandbox Account on the test device, not
   your real Apple ID).

## 10. Submit for review

1. App Store Connect → your app → create a new version, attach the build from
   TestFlight.
2. Fill in **App Review Information**: a demo account (Supabase test user + password)
   since Kept requires sign-in, and notes mentioning the UGC moderation tools from step 8.
3. Submit. First-time review is commonly 24-48 hours, sometimes longer; subsequent
   updates are usually faster.
4. If rejected, the Resolution Center message tells you the specific guideline — the most
   likely first-round issues for an app like this are: missing Guideline 1.2
   report/block, subscription terms not clearly disclosed near the purchase button
   (`PaywallView`'s footnote text handles this), or the demo account not working.

## Ongoing after launch

- Watch **App Store Connect → Sales and Trends** and **Analytics** for conversion on the
  Kept+ paywall.
- App Store Server Notifications (Apple → your server) are optional but worth adding
  later if you want subscription state mirrored server-side (e.g. to gate something
  Circle-related for non-subscribers outside the app) — `Supabase/schema.sql`'s closing
  comment notes where that would plug in; it isn't required for the app to correctly gate
  Kept+ features, which are decided on-device via StoreKit 2 entitlements.
