# Testing record (Phase 4)

## Automated tests

`flutter test` runs 220 tests in CI on every pull request.

| Area | What is covered |
|---|---|
| Hard rules | Every veto, the boundaries (deadline exactly now, time zones), and missing data, which warns instead of vetoing |
| Rule integrity | An AI that always answers BID never produces a BID for expired, wrong-country or wrong-sector tenders, and is never called for them |
| Bid agent | Quote verification, guards, retries, timeouts, malformed answers, `ai_unavailable` |
| Sources | TED and World Bank clients against recorded live responses, failure handling, country names |
| Sync | Dedup, pruning, Firestore failure and offline timeout, per-sync AI limit, verdict reuse |
| Workflow | Watch, request approval, owner decision, checklist, stages, loss reasons |
| Reminders | 7/3/1-day plan, past times skipped, Monday digest |
| Scan | Lenient parsing, required confirmations, the turnover rule on scanned notices |
| Insights | Win rate, AI agreement, fit bands, best buyers and sectors |
| Accessibility | Every page with realistic data, in light and dark: 48 dp tap targets, labelled controls, WCAG text contrast |
| Error states | Pages show an error with a retry, never a fake empty state |

The evaluation harness (objective O2) is separate: see `eval/README.md`.

## Devices (2 Nov 2026)

| Device | Screen | Android |
|---|---|---|
| Pixel 10 emulator | 1080 × 2424 | 36.1 |
| Small Phone emulator | 720 × 1280 | 36.1 |

Both devices ran a debug build against the live Firebase project, with App Check debug tokens.

| Check | Pixel 10 | Small Phone |
|---|---|---|
| Sign-in, onboarding | Owner (existing account) | Bid manager (new account, joined through the invite) |
| Live TED and World Bank sync, AI judging | Pass | Pass |
| Invite → join as bid manager (cross-device) | Sent | Received and joined |
| Bid manager: no Approvals button, read-only Company page | n/a | Pass |
| Bid manager asks for approval → owner approves (cross-device) | Approved | Updated live: Preparing, with the owner's note |
| Landscape on every tab and on Tender detail | No overflow errors | No overflow errors |
| Cold start in airplane mode | | Signed in, feed from the cache, pipeline from the Firestore cache |
| Sync in airplane mode | "no connection" per source in 2 s | |
| Background sync (WorkManager) | Worker SUCCESS, notification | |
| Deadline reminders scheduled (`dumpsys alarm`) | Pass | |
| Camera preview and scan (sample notice) | Pass | |

### Bugs found and fixed in this phase
- **Sign-in buttons:** they were drawn disabled for the first frames, because `build()` was async. The contrast check caught it.
- **Endless spinners:** while Riverpod retried a failed stream, pages showed a spinner forever. The error is now checked first on 5 pages.
- **Fake empty states:** Deadlines, Approvals and Insights showed an empty state when bids failed to load. They now show an error with a retry.
- **Truncated helper text:** on the 720 px phone, helper text was cut off. It now wraps.
- **Unreadable chart colours (Phase 3):** the verdict-mix bar used colours that failed colour-blind separation. The colours are now validated.

## Not yet done (needs the team)

- **Objective O2 labels:** label the 50 notices in `eval/labels.csv`, then re-run `tool/eval/report.py`.
- **Objective O3, real firms:** review 10 verdicts with 1 or 2 real small firms. A suggested protocol:
  1. Get consent. Send Gemini only data the firm agreed to share, or use its public profile only.
  2. Create the firm's profile, sync, and pick 10 judged tenders, both BID and not BID.
  3. For each tender, the firm says what it would do and why, *before* seeing BidRadar's verdict.
  4. Record agreement, and the firm's view of the quoted evidence ("useful", "wrong", "missing").
  5. Note time saved compared with the firm's usual way of finding tenders.
- **Physical phone:** test on at least one real Android phone. Play Integrity App Check needs a release build from Play, or keep the debug provider for the demo.
- **Clean-up after testing:** delete the App Check debug tokens in the Firebase console.
