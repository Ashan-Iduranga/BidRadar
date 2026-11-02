# Evaluation (objective O2)

The proposal promises: hand-label 50 real notices for the 3 sample profiles,
run the agent on them, and report agreement with the labels and quote
accuracy (100% after verification).

| File | What it is |
|---|---|
| `notices.json` | The frozen dataset: 50 real, open notices from EU TED and the World Bank (fetched 2 Nov 2026), each assigned to a synthetic profile. |
| `labels.csv` | The labelling sheet. **The team fills the `label` column.** |
| `results.json` | Raw per-notice output of the last harness run. |
| `REPORT.md` | The generated report. Do not edit by hand. |

## Labelling (team task)

Labels must be made by people. An AI-made answer key would make the
agreement figure meaningless.

For each row of `labels.csv`:
1. Open the notice (`url`) and the profile in `assets/seed/sample_companies.json`.
2. Decide what a careful bid manager would do:
   - `BID`: the firm is eligible and the work fits.
   - `NO_BID`: ineligible (country, sector, turnover, deadline) or clearly the wrong work.
   - `REVIEW`: cannot tell from the notice alone, for example because key requirements are only in the tender documents.
3. Put your initials in `labeller`. Add a short reason in `notes` when it is not obvious.

Ideally two people label each notice independently and agree on the
disagreements. Write the agreed label in `label`, and note the raw
inter-labeller agreement in the final report.

## Re-running

```bash
# 1. Run the real pipeline on a device or emulator (about 3 minutes, about 40 Gemini calls)
flutter test integration_test/eval_test.dart -d <device> > eval_run.log
# 2. Build the report (it joins the human labels automatically)
python tool/eval/report.py eval_run.log eval/labels.csv
```

To rebuild the dataset from live sources (this changes the notices, so labels must be redone):
`flutter test tool/eval/build_dataset_test.dart`.

## Notes on the first run (2 Nov 2026)

- **Rule integrity:** 0 BID verdicts on the 10 rule-vetoed notices. The AI is never called for them.
- **Quote accuracy:**
  - 96.7% of quotes were verbatim before verification (2 of 61 were not).
  - Both bad quotes were caught: the agent retried, and one notice ended as `quotes_rejected`, which becomes REVIEW.
  - Accepted verdicts are 100% verified, by construction.
- **Limitation:** Gemini 3.5 Flash-Lite cites few criteria (about 1.5 per notice), so the evidence per verdict is thin. A larger model would likely give more criteria per notice. It is a one-line change in `GeminiModel.defaultModel`, but the larger free model was too slow on this project.
- **Many NO_BIDs:** most World Bank notices in the IT profile's countries are civil works or goods, so NO_BID is often right. Only the human labels can confirm it.
- **Construction profile topped up:** it serves Sri Lanka and the Maldives, which had only 6 open notices, so 10 notices from neighbouring countries were added. The rules veto these on country, as designed.
