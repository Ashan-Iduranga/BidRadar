# BidRadar

An AI bid or no-bid agent that finds public tenders and judges them for small firms.
SE303.3 Mobile Application Development group project, NSBM, 2026.

Team: Hasitha Bandara (lead), Ashan Iduranga, Dinuja Ransara, Sewmin Menuja.
Plans: `BidRadar_Proposal.pdf` and `BidRadar_Architecture_and_Implementation_Plan.pdf`.

## Status

- Phase 0 (foundations): done.
- Phase 1 (plumbing and data): done.
  - Sign-up, onboarding (create a company, start from a sample, or accept or decline an invite). Invites show up live. Accepting or declining needs a verified email, because an invite is addressed to an email and anyone could register that address first. Onboarding offers Resend and "I have verified".
  - Owner and bid manager roles; Approvals is owner-only.
  - Sign-out clears the phone's cached tenders, verdicts and sync log, so the next account on the phone starts clean.
  - Company page saved to Firestore.
  - Live TED and World Bank clients, the drift cache with dedup, and `EligibilityRules`.

- Phase 2 (automation core and feed): done.
  - `FeedSync` (`lib/domain/sync/feed_sync.dart`) runs the pipeline: fetch, drop notices that have already closed (to the minute), dedup, hard rules, cache, Firestore. Vetoed tenders get a `rules_veto` NO_BID audit verdict and never reach the AI. A veto already recorded is not written again.
  - Background sync every 6 hours with WorkManager, with the notification "N new tenders match". "Sync now" and pull to refresh run the same code.
  - Feed: status, source and sector filters, ranking, an "Updated … ago" line, and offline reading.
  - Tender detail: facts, rule results, the notice text, Open notice, and Share.

- Phase 3 (AI agent and workflow): done.
  - **Bid agent:** Gemini (`gemini-3.5-flash-lite`, free tier) through Firebase AI Logic. Every model is built in 1 place, `GeminiFactory`.
    - App Check: each call carries the phone's App Check token. If the phone cannot get a token, the call is retried once without one. The server accepts that retry only while App Check enforcement is off for AI Logic.
    - The prompt marks the notice text as untrusted data, not instructions.
    - Every quote must appear in the notice word for word, as whole words, and be at least 3 words long. If a quote is not found, the AI is asked once more and told which quotes failed; after that the verdict is REVIEW.
    - Guards run after the AI: a rules veto forces NO_BID. A NO_BID needs at least 1 requirement quoted as not met. A BID needs every requirement met with evidence. Low confidence or fit and rule warnings force REVIEW.
    - Each tender gets at most 3 AI calls, each with a 20 s timeout. Quota, request-limit and access errors stop the sync at once and are not retried. A notice that fails 3 syncs in a row is left for a person.
    - Verdicts are cached by notice hash and by a fingerprint of the company profile, so editing the profile gets tenders judged again. Each sync judges at most 5 tenders.
  - **Pipeline and Approvals:** Watching, Preparing, Submitted, Won and Lost.
    - Only the owner approves, and the Firestore rules enforce it on every bid write, including when a bid is created. A bid manager may only ask for approval, move an approved bid from Preparing to Submitted and then Won or Lost, and tick or add checklist tasks.
    - Each change writes only the fields it changed, so 2 phones changing different parts of the same bid never undo each other. Approving runs in a transaction, so it needs a connection.
    - Approval builds the document checklist from the verdict.
    - Lost bids record their reasons.
  - **Deadlines:** reminders 7, 3 and 1 days before each deadline at 09:00, and a Monday digest.
  - **Scan:** camera, then ML Kit OCR on the device, then Gemini; the user confirms the buyer and deadline.
  - **Insights:** win rate, AI agreement, verdict mix, the fit-score chart, loss reasons, and best buyers and sectors. Gemini suggests profile changes, and the owner accepts them.

- Phase 4 (hardening and evaluation): done on branch `phase-4`.
  - Accessibility tests run on every page, and the bugs they found were fixed.
  - Manual tests on 2 emulators: the owner and bid manager flow across 2 phones, rotation, and offline restart. These are checked by hand, not by CI. See `docs/TESTING.md`.
  - The O2 evaluation on 50 real notices. See `eval/README.md` and `docs/TESTING.md`. `eval/REPORT.md` was made before the stricter guards and quote checks of 27 Nov 2026, so re-run it before quoting its numbers.
  - **Team task:** label `eval/labels.csv` (O2) and run the real-firm review (O3).

Model note: `gemini-3.8-flash` is also free, but it did not answer within 90 s on this project, so the app uses 3.5 Flash-Lite. The model name lives in `GeminiModel.defaultModel`.

### Testing background sync

Android won't run periodic WorkManager jobs early, even when they are forced through `adb`. In debug builds, the Feed's overflow menu has **Run background sync (debug)**. It queues the same task once, in the background isolate.

### Testing Scan on an emulator

The emulator camera can't see paper. In debug builds the Scan page has **Try a sample notice (debug)**, which runs the real OCR and AI on `assets/samples/sample_notice.png`, a synthetic notice with a deadline of 30 June 2027. To change the date, edit the constant in `tool/render_sample_notice.py` and run it again. Reprint any paper copy after a change.

Source notes found while building Phase 1:
- TED's `ACTIVE` scope still returns notices that closed years ago, oldest first. The client asks for open deadlines by date, newest first, and `FeedSync` then drops any notice that closed earlier the same day.
- TED publishes a change notice under a new number, usually with the same text. It counts as a duplicate, but if it comes from the same buyer with a later deadline, the cached tender takes that deadline.
- World Bank notices have no CPV codes and give the country as a name. The sector rule only warns on them, and `lib/core/geo/countries.dart` maps names to alpha-3.
- World Bank deadlines and dates found in notice text have no time zone. They are read as local time in the buyer's country (`lib/core/geo/local_time.dart`). For a regional or unknown country, the earliest possible time is used and the notice text says so.
- Neither source states a minimum turnover in a structured field, so the turnover rule fires only when one is known (from scanned notices in Phase 3).

Firebase project: `bidradar-se303`. Firestore is in `asia-south1` (Mumbai). The security rules in `firestore.rules` are newer than the deployed ones until someone runs `firebase deploy --only firestore:rules`. After deploying, install the new build on every phone, because the new rules refuse some writes from older builds. The Android app (`com.bidradar.app`) is registered with the debug SHA-1 and SHA-256 fingerprints. The steps below are kept for reference, and for anyone who needs to set it up again.

## Demo checklist

Before recording the demo or the final video:
1. Deploy the rules: `firebase deploy --only firestore:rules`.
2. Install the same new build on both phones. Use a debug build if the demo uses **Try a sample notice (debug)**; release builds use Play Integrity, which a sideloaded APK may not pass.
3. Register each phone's App Check debug token after its final install (see Firebase setup below). A reinstall makes a new token.
4. Verify the bid manager's email before the demo, and keep that inbox open on phone 2.
5. Delete leftover test invites from other companies in the Firebase console.
6. Sync on both phones before recording. After a sign-out or a profile edit, tenders are judged again, up to 5 per sync.
7. Allow notifications when the app first asks, so the reminders and the "new tenders" notification show.

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
   - **App Check**: register the Android app with Play Integrity. For debug builds, run the app once, copy the debug token from logcat (`adb logcat | grep DebugAppCheckProvider`) and add it under App Check, then Manage debug tokens. Each fresh install makes a new debug token, so register it again after reinstalling. Play Integrity expects a build distributed through Google Play, so a sideloaded release APK may get no token. Use a debug or profile build with a registered debug token for the demo.
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
- **Profile:** opened from the avatar at the top right of every page. It holds the theme (System / Light / Dark) and the notification settings, which are stored on the device. The notification switches also follow Android's permission: the app asks for it once when the main pages first open, and if it is blocked the switches show off with an "Open settings" button.

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
- CI (`.github/workflows/ci.yml`) must pass: format, analyze, test, a debug APK build, and the Firestore rules tests (`tool/rules_test`, run on the local emulator with a demo project, never the live one). To run the rules tests locally: `cd tool/rules_test && npm ci && npm test` (needs Node and Java 21).
- Every network call goes through `ResilientHttp`.
- Every AI call goes through `AiModel`.
- Only synthetic or consented data is sent to Gemini.
