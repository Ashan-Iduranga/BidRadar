# BidRadar evaluation (objective O2)

Notices: **50** real notices from EU TED and the World Bank, split across 3 synthetic company profiles. Run with `gemini-3.5-flash-lite` through the app's own pipeline: hard rules, then Gemini, then quote verification, then guards.

## Pipeline

| Measure | Result |
|---|---|
| Removed by hard rules (AI never called) | 20.0% (10/50) |
| BID verdicts on rule-vetoed notices | **0** (must be 0) |
| Sent to the AI | 40 |
| AI answered | 100.0% (40/40) |
| Status: accepted | 39 |
| Status: quotes_rejected | 1 |
| AI latency, median / max | 2.0 s / 3.6 s |

## Quote accuracy

| Measure | Result |
|---|---|
| Quotes found verbatim in the notice, **before** verification | 96.7% (59/61) |
| Quotes verified in **accepted** verdicts (target 100%) | 100.0% (59/59) |

## Verdicts

| Verdict | Count |
|---|---|
| BID | 1 |
| REVIEW | 9 |
| NO_BID | 40 |

Veto reasons: country_not_served 10

## Agreement with human labels

No notices are labelled yet. Fill the `label` column of `eval/labels.csv` (BID, NO_BID or REVIEW, judged by a team member from the notice and the profile), then re-run this script.

## Per profile

| Profile | Notices | Vetoed | BID | REVIEW | NO_BID |
|---|---|---|---|---|---|
| sample-build-supply | 16 | 10 | 0 | 2 | 14 |
| sample-consult-eu | 17 | 0 | 1 | 5 | 11 |
| sample-it-lanka | 17 | 0 | 0 | 2 | 15 |
