# Testing record (Phase 4)

## Automated tests

`flutter test` runs 343 tests in CI on every pull request (232 before the 27 Nov 2026 fixes).

| Area | What is covered |
|---|---|
| Hard rules | Every veto, the boundaries (deadline exactly now, time zones), and missing data, which warns instead of vetoing |
| Rule integrity | An AI that always answers BID never produces a BID for expired, wrong-country or wrong-sector tenders, and is never called for them |
| Bid agent | Quote verification on whole words (at least 3 words), guards (NO_BID needs a requirement not met, BID needs every requirement known), the 3-call cap, quota and request-limit errors, rejected quotes named on retry, timeouts, malformed answers, `ai_unavailable` |
| AI setup | The App Check fallback, the profile fingerprint, the prompt treating notice text as data |
| Sources | TED and World Bank clients against recorded live responses, failure handling, country names, local time zones for deadlines, TED change notices |
| Sync | Dedup, notices that closed earlier today, repeated vetoes, 1 failing notice not blocking the rest, pruning, Firestore failure and offline timeout, per-sync AI limit, verdict reuse by notice and profile, database migrations |
| Workflow | Watch, request approval, owner decision, checklist, stages, loss reasons, writing only changed fields, failed or queued writes reported as such |
| Session | Live invites with decline, verified email for invites, loading while membership loads, sign-out clearing local data, bid listeners ending |
| Reminders | 7/3/1-day plan, past times skipped, Monday digest, plans applied 1 at a time with the latest winning, the notification permission and the Profile switches |
| Scan | Lenient parsing, required confirmations shown under each field, a failed save keeping the form, any year in the date picker, the turnover rule on scanned notices, verdicts stored with the profile |
| Insights | Win rate, AI agreement, fit bands, best buyers and sectors |
| Accessibility | Every page with realistic data, in light and dark: 48 dp tap targets, labelled controls, WCAG text contrast. The Deadlines calendar and bid cards at 200% text on a small phone |
| Error states | Pages show an error with a retry, never a fake empty state. Offline saves and invites end after 10 s |

The Firestore security rules have their own tests in `tool/rules_test/rules.test.mjs`, run on the local emulator with a demo project ID, never the live project. CI runs them in a separate job. They cover owner-only approval on create and update, what a bid manager may change, invites (re-send, clash, verified email) and the shape of tender documents.

The evaluation harness (objective O2) is separate: see `eval/README.md`.

## Manual checks on devices (2 Nov 2026)

These checks are done by hand on 2 emulators. CI does not run them.

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

**Re-run after the 27 Nov 2026 fixes.** These rows were checked before the fixes and need checking again with the new build and the newly deployed rules:
- Invite and join across 2 phones: the bid manager's email must now be verified first.
- Ask for approval and approve across 2 phones: the rules now check every bid write, and approving needs a connection.
- Background sync notification: it now uses a white status bar icon.
- Camera and sample scan: the camera is released when the app leaves the foreground, and the sample notice now closes on 30 June 2027.
- Notification permission: it is now asked when the main pages first open, not after the first sync.

### Bugs found and fixed in Phase 4
- **Sign-in buttons:** they were drawn disabled for the first frames, because `build()` was async. The contrast check caught it.
- **Endless spinners:** while Riverpod retried a failed stream, pages showed a spinner forever. The error is now checked first on 5 pages.
- **Fake empty states:** Deadlines, Approvals and Insights showed an empty state when bids failed to load. They now show an error with a retry.
- **Truncated helper text:** on the 720 px phone, helper text was cut off. It now wraps.
- **Unreadable chart colours (Phase 3):** the verdict-mix bar used colours that failed colour-blind separation. The colours are now validated.

### Fixed after the code review (27 Nov 2026)

A review of the whole app before the next phase found these problems. Each fix has its own commit and tests.
- **Demo sample expired:** the sample notice closed on 28 Nov 2026, so Scan would have vetoed it during the demo. It now closes on 30 June 2027, and `tool/render_sample_notice.py` re-renders it.
- **1 bad notice stopped all AI judging:** a notice the AI could not answer stopped the whole sync. Now only quota, request-limit, access or connection errors stop it, and a notice that fails 3 syncs in a row is left for a person.
- **Duplicate veto broke the cloud save:** a veto already recorded by another phone was written again in the same batch as everything else, and the rules refused the whole batch. Vetoes are now written 1 at a time, and an existing one is skipped.
- **Owner approval could be skipped:** the rules checked updates but not creation, so a bid manager could create a bid that was already approved. Creation is now checked too.
- **Notification permission asked too late:** it was asked after the first sync, so reminders scheduled before that were silent. It is now asked when the main pages first open.
- **Weak guards and quotes:** a NO_BID needed no evidence, a BID could pass with unknown requirements, and a 2-word quote could match anywhere. All 3 are now checked.
- **Lost updates:** saving a bid wrote the whole document, so 2 phones undid each other. Only changed fields are written now.
- **Time zones:** World Bank deadlines were read as UTC, about 5.5 hours late for Sri Lanka. They are now read in the buyer's local time.
- **Smaller fixes:** invites (live, decline, re-send, verified email, offline), sign-out clearing local data, the onboarding flash after sign-in, failed writes shown as success, scan form and camera lifecycle, the date picker range, the camera preview shape, offline saves that never ended, reminder plans racing, the notification icon, the profile fingerprint on verdicts, and layouts at 200% text.

## Not yet done (needs the team)

- **Deploy the new rules** with `firebase deploy --only firestore:rules`, then install the new build on every phone.

- **Objective O2 labels:** label the 50 notices in `eval/labels.csv`, then re-run `tool/eval/report.py`.
- **Objective O3, real firms:** review 10 verdicts with 1 or 2 real small firms. A suggested protocol:
  1. Get consent. Send Gemini only data the firm agreed to share, or use its public profile only.
  2. Create the firm's profile, sync, and pick 10 judged tenders, both BID and not BID.
  3. For each tender, the firm says what it would do and why, *before* seeing BidRadar's verdict.
  4. Record agreement, and the firm's view of the quoted evidence ("useful", "wrong", "missing").
  5. Note time saved compared with the firm's usual way of finding tenders.
- **O2 report out of date:** `eval/REPORT.md` was made before the stricter guards and quote checks. Re-run the evaluation before quoting its numbers.
- **Physical phone:** test on at least one real Android phone, using the "Re-run" list above. Play Integrity App Check expects a build from Google Play, so use a debug build with a registered debug token for the demo.
- **Clean-up after testing:** delete the App Check debug tokens in the Firebase console.
