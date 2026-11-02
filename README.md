# BidRadar

An AI bid or no-bid agent that finds public tenders and judges them for small firms.
SE303.3 Mobile Application Development group project, NSBM, 2026.

Team: Hasitha Bandara (lead), Ashan Iduranga, Dinuja Ransara, Sewmin Menuja.
Plans: `BidRadar_Proposal.pdf` and `BidRadar_Architecture_and_Implementation_Plan.pdf`.

## Status

- Phase 0 (foundations): done.
- Phase 1 (plumbing and data): done on branch `phase-1`.
  - Sign-up, onboarding (create a company, start from a sample, or accept an invite).
  - Owner and bid manager roles; Approvals is owner-only.
  - Company page saved to Firestore.
  - Live TED and World Bank clients, the drift cache with dedup, and `EligibilityRules`.

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

Material 3 from a single cobalt seed (`#2F4BD8`). It follows the team's `material-3` and `quiet-product` style guides:
- Borders, not shadows.
- One accent colour per screen.
- 4/8 dp spacing.
- Meaning never shown by colour alone.

Verdict colours live in a `StatusColors` theme extension with light and dark variants. Tokens are in `lib/core/theme/`.

Shared widgets: `VerdictChip`, `FitScoreBadge`, `TenderCard`, `EmptyState`, `ErrorState`.

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
