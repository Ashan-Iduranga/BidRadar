# BidRadar

An AI bid or no-bid agent that finds public tenders and judges them for small firms.
SE303.3 Mobile Application Development group project, NSBM, 2026.

Team: Hasitha Bandara (lead), Ashan Iduranga, Dinuja Ransara, Sewmin Menuja.
Plans: `BidRadar_Proposal.pdf` and `BidRadar_Architecture_and_Implementation_Plan.pdf`.

## Status

- Phase 0 (foundations): done.
- Phase 1 (plumbing and data): done.
  - Sign-up, onboarding (create a company, start from a sample, or accept an invite).
  - Owner and bid manager roles; Approvals is owner-only.
  - Company page saved to Firestore.
  - Live TED and World Bank clients, the drift cache with dedup, and `EligibilityRules`.

- Phase 2 (automation core and feed): done.
  - `FeedSync` (`lib/domain/sync/feed_sync.dart`) runs the pipeline: fetch, dedup, hard rules, cache, Firestore. Vetoed tenders get a `rules_veto` NO_BID audit verdict and never reach the AI.
  - Background sync every 6 hours with WorkManager, with the notification "N new tenders match". "Sync now" and pull to refresh run the same code.
  - Feed: status, source and sector filters, ranking, an "Updated … ago" line, and offline reading.
  - Tender detail: facts, rule results, the notice text, Open notice, and Share.

- Phase 3 (AI agent and workflow): done.
  - **Bid agent:** Gemini (`gemini-3.5-flash-lite`, free tier) through Firebase AI Logic, protected by App Check.
    - Every quote must appear word for word in the notice: one retry, then REVIEW.
    - Guards run after the AI: a rules veto forces NO_BID; low confidence or fit, unmet or missing evidence, and rule warnings force REVIEW.
    - Each call has a 20 s timeout and 2 retries, then "AI unavailable".
    - Verdicts are cached by notice hash, and each sync judges at most 5 tenders.
  - **Pipeline and Approvals:** Watching, Preparing, Submitted, Won and Lost.
    - Only the owner approves; this is enforced in the Firestore rules.
    - Approval builds the document checklist from the verdict.
    - Lost bids record their reasons.
  - **Deadlines:** reminders 7, 3 and 1 days before each deadline at 09:00, and a Monday digest.
  - **Scan:** camera, then ML Kit OCR on the device, then Gemini; the user confirms the buyer and deadline.
  - **Insights:** win rate, AI agreement, verdict mix, the fit-score chart, loss reasons, and best buyers and sectors. Gemini suggests profile changes, and the owner accepts them.

- Phase 4 (hardening and evaluation): done on branch `phase-4`.
  - Accessibility tests run on every page, and the bugs they found were fixed.
  - Two-device tests: the owner ↔ bid-manager flow, rotation, and offline restart.
  - The O2 evaluation on 50 real notices. See `eval/README.md` and `docs/TESTING.md`.
  - **Team task:** label `eval/labels.csv` (O2) and run the real-firm review (O3).

Model note: `gemini-3.8-flash` is also free, but it did not answer within 90 s on this project, so the app uses 3.5 Flash-Lite. The model name lives in `GeminiModel.defaultModel`.

### Testing background sync

Android won't run periodic WorkManager jobs early, even when they are forced through `adb`. In debug builds, the Feed's overflow menu has **Run background sync (debug)**. It queues the same task once, in the background isolate.

### Testing Scan on an emulator

The emulator camera can't see paper. In debug builds the Scan page has **Try a sample notice (debug)**, which runs the real OCR and AI on `assets/samples/sample_notice.png`, a synthetic notice.

Source notes found while building Phase 1:
- TED's `ACTIVE` scope still returns notices that closed years ago, oldest first. The client filters on open deadlines and sorts newest first.
- World Bank notices have no CPV codes and give the country as a name. The sector rule only warns on them, and `lib/core/geo/countries.dart` maps names to alpha-3.
- Neither source states a minimum turnover in a structured field, so the turnover rule fires only when one is known (from scanned notices in Phase 3).

Firebase project: `bidradar-se303`. Firestore is in `asia-south1` (Mumbai) and the security rules are deployed. The Android app (`com.bidradar.app`) is registered with the debug SHA-1 and SHA-256 fingerprints. The steps below are kept for reference, and for anyone who needs to set it up again.

## Getting started

Requirements: Flutter 3.47.x (Dart 3.13), Android SDK, JDK 17 or newer.

```bash
flutter pub get
flutter run            # on a phone or emulator
flutter test           # unit and widget tests
flutter analyze        # must be clean before a PR
```

If Firebase is not configured yet, the app still runs. It shows a banner and skips sign-in.

### Windows note

If the project is on a different drive from the pub cache (for example D: and C:), Kotlin incremental builds fail with "Could not close incremental caches". `android/gradle.properties` sets `kotlin.incremental=false` to avoid this.

## Firebase setup (one person does this once)

1. Create a Firebase project on the free Spark plan in the [Firebase console](https://console.firebase.google.com).
2. Connect the app. This overwrites `lib/firebase_options.dart` and adds `android/app/google-services.json`:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<project-id> --platforms=android --android-package-name=com.bidradar.app
   ```
3. In the console, turn on:
   - **Authentication**: the Email/Password provider.
   - **Firestore**: create the database, then deploy the rules with `firebase deploy --only firestore:rules`.
   - **AI Logic**: the Gemini Developer API (free tier).
   - **App Check**: register the Android app with Play Integrity. For debug builds, run the app once, copy the debug token from logcat (`adb logcat | grep DebugAppCheckProvider`) and add it under App Check, then Manage debug tokens.
4. Add teammates under Project settings, then Users and permissions.

The Firebase client config is not a secret: access is protected by security rules and App Check. Still, never commit service-account keys or `.env` files.

## Architecture

The app follows Flutter's MVVM guide: Page → Riverpod ViewModel → Service → Repository.

```
lib/
  core/       theme tokens, router, logging, ResilientHttp (20 s timeout, 2 retries)
  data/       models (the Firestore contract), sources (TED, World Bank), local cache, repositories
  domain/     rules (EligibilityRules), agent (AiModel, BidAgent, QuoteVerifier, schema), sync
  ui/         one folder per page, plus shared widgets
```

### Contracts agreed in Phase 0

| Contract | File |
|---|---|
| Firestore data model (`companies`, `profiles`, `tenders`, `verdicts`, `bids`, `approvals`) | `lib/data/models/` |
| Hard-rule result (`RulesResult`, `RuleVeto`, `VetoRule`) | `lib/data/models/verdict.dart` |
| Gemini response schema (verdict, scanned notice) | `lib/domain/agent/verdict_schema.dart` |
| Swappable AI interface plus strict parsing | `lib/domain/agent/ai_model.dart` |
| Security rules | `firestore.rules` |
| 3 sample companies (synthetic) | `assets/seed/sample_companies.json` |

Conventions:
- Countries use ISO 3166-1 alpha-3 codes (`LKA`).
- CPV codes are 8 digits with no check digit.
- Dates are stored as ISO 8601 UTC strings.
- Enums are stored by their `wire` value.

### Design system

"Ember Slate" direction, on Material 3. Mockups are in the team's Claude Design canvas "BidRadar redesign" (direction A).
- **Palette:** grey-blue ground `#DEE6E8`, white cards with soft shadows, one black hero card per screen, mustard `#DBB144` accent.
- **Orange:** `#FF5C00` is used as a fill with dark text on it (buttons, the nav pill). Where orange is text, it is `#B33F00` so it passes 4.5:1.
- **Font:** Plus Jakarta Sans, bundled in `assets/fonts` (OFL).
- **Layout:** 4/8 dp spacing; meaning is never shown by colour alone.
- **Motion:** Material 3 timings in `lib/core/theme/motion.dart`. Every animation is turned off when Android's "Remove animations" is on.
- **Intro:** a 3-step animated intro before sign-in on first launch, replayable from Profile.
- **Profile:** opened from the avatar at the top right of every page. It holds the theme (System / Light / Dark) and the notification settings, which are stored on the device.

Theme extensions:
- `StatusColors`: verdict colours; Review is violet so it never reads as the orange action colour.
- `BrandColors`: ground, hero and nav colours.

Tokens are in `lib/core/theme/`.

Shared widgets: `BrandAppBar`, `AvatarButton`, `VerdictChip`, `FitScoreBadge`, `TenderCard`, `EmptyState`, `ErrorState`, and skeleton loaders.

## Who builds what

| Member | Owns |
|---|---|
| Hasitha | Firebase, security rules, App Check, BidAgent and QuoteVerifier, page 2 (Tender detail), CI |
| Ashan | TED and World Bank clients, FeedSync, dedup, pages 1 (Feed) and 4 (Scan) |
| Dinuja | EligibilityRules with tests, workmanager, reminders, notifications, pages 3 (Company) and 6 (Deadlines) |
| Sewmin | Pipeline, approvals, insights, pages 5, 7 and 8, design system |

## How we work

- `main` is protected. Use short feature branches and reviewed pull requests.
- CI (`.github/workflows/ci.yml`) must pass: format, analyze, test, and a debug APK build.
- Every network call goes through `ResilientHttp`.
- Every AI call goes through `AiModel`.
- Only synthetic or consented data is sent to Gemini.
