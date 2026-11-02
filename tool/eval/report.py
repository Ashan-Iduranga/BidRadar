"""Turns the O2 harness output into eval/results.json and eval/REPORT.md.

Usage:
    python tool/eval/report.py <harness log> [eval/labels.csv]

The log is the stdout of
    flutter test integration_test/eval_test.dart -d <device>
Agreement with human labels is reported only for rows a person labelled
(label column = BID, NO_BID or REVIEW).
"""
import csv
import json
import os
import sys
from collections import Counter

KINDS = ["BID", "REVIEW", "NO_BID"]


def load_results(log_path):
    rows = []
    with open(log_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            i = line.find("EVAL_RESULT ")
            if i >= 0:
                rows.append(json.loads(line[i + len("EVAL_RESULT "):]))
    return rows


def load_labels(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return {
            r["tender_id"] + "|" + r["profile"]: r["label"].strip().upper()
            for r in csv.DictReader(f)
            if r["label"].strip().upper() in KINDS
        }


def pct(a, b):
    return "n/a" if b == 0 else f"{100 * a / b:.1f}% ({a}/{b})"


def main():
    log = sys.argv[1]
    labels = load_labels(sys.argv[2] if len(sys.argv) > 2 else "eval/labels.csv")
    rows = load_results(log)
    os.makedirs("eval", exist_ok=True)
    with open("eval/results.json", "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=1)

    judged = [r for r in rows if r["rules_passed"]]
    vetoed = [r for r in rows if not r["rules_passed"]]
    ok = [r for r in judged if r.get("status") not in ("error", "ai_unavailable")]
    raw_q = sum(r.get("raw_quotes", 0) for r in ok)
    raw_v = sum(r.get("raw_quotes_verified", 0) for r in ok)
    acc = [r for r in ok if r.get("status") == "accepted"]
    acc_q = sum(r.get("final_quotes", 0) for r in acc)
    acc_v = sum(r.get("final_quotes_verified", 0) for r in acc)
    status = Counter(r.get("status") for r in judged)
    final = Counter(r["final_verdict"] for r in rows)
    lat = sorted(r["latency_ms"] for r in ok if "latency_ms" in r)
    vetoes = Counter(v for r in vetoed for v in r["vetoes"])
    bid_on_veto = sum(1 for r in vetoed if r["final_verdict"] == "BID")

    labelled = [
        (r, labels[r["tender_id"] + "|" + r["profile"]])
        for r in rows
        if r["tender_id"] + "|" + r["profile"] in labels
    ]
    agree = sum(1 for r, l in labelled if r["final_verdict"] == l)
    # Strict "would we bid" agreement: BID vs not-BID.
    agree_bid = sum(
        1 for r, l in labelled if (r["final_verdict"] == "BID") == (l == "BID")
    )
    confusion = Counter((l, r["final_verdict"]) for r, l in labelled)

    out = []
    w = out.append
    w("# BidRadar evaluation (objective O2)\n")
    w(f"Notices: **{len(rows)}** real notices from EU TED and the World Bank, "
      "split across 3 synthetic company profiles. Run with "
      "`gemini-3.5-flash-lite` through the app's own pipeline: "
      "hard rules, then Gemini, then quote verification, then guards.\n")
    w("## Pipeline\n")
    w("| Measure | Result |\n|---|---|")
    w(f"| Removed by hard rules (AI never called) | {pct(len(vetoed), len(rows))} |")
    w(f"| BID verdicts on rule-vetoed notices | **{bid_on_veto}** (must be 0) |")
    w(f"| Sent to the AI | {len(judged)} |")
    w(f"| AI answered | {pct(len(ok), len(judged))} |")
    for k in ["accepted", "quotes_rejected", "ai_unavailable", "error"]:
        if status.get(k):
            w(f"| Status: {k} | {status[k]} |")
    if lat:
        w(f"| AI latency, median / max | {lat[len(lat) // 2] / 1000:.1f} s / "
          f"{lat[-1] / 1000:.1f} s |")
    w("")
    w("## Quote accuracy\n")
    w("| Measure | Result |\n|---|---|")
    w(f"| Quotes found verbatim in the notice, **before** verification | "
      f"{pct(raw_v, raw_q)} |")
    w(f"| Quotes verified in **accepted** verdicts (target 100%) | "
      f"{pct(acc_v, acc_q)} |")
    w("")
    w("## Verdicts\n")
    w("| Verdict | Count |\n|---|---|")
    for k in KINDS:
        w(f"| {k} | {final.get(k, 0)} |")
    if vetoes:
        w("")
        w("Veto reasons: " + ", ".join(f"{k} {v}" for k, v in vetoes.most_common()))
    w("")
    w("## Agreement with human labels\n")
    if not labelled:
        w("No notices are labelled yet. Fill the `label` column of "
          "`eval/labels.csv` (BID, NO_BID or REVIEW, judged by a team member "
          "from the notice and the profile), then re-run this script.")
    else:
        w(f"Labelled: {len(labelled)} of {len(rows)}.\n")
        w("| Measure | Result |\n|---|---|")
        w(f"| Exact agreement (3 classes) | {pct(agree, len(labelled))} |")
        w(f"| Bid / no-bid agreement | {pct(agree_bid, len(labelled))} |")
        w("")
        w("Confusion (rows: human label, columns: BidRadar):\n")
        w("| | " + " | ".join(KINDS) + " |\n|---|" + "---|" * len(KINDS))
        for h in KINDS:
            w(f"| {h} | " + " | ".join(str(confusion.get((h, b), 0)) for b in KINDS) + " |")
    w("")
    w("## Per profile\n")
    w("| Profile | Notices | Vetoed | BID | REVIEW | NO_BID |\n|---|---|---|---|---|---|")
    for p in sorted({r["profile"] for r in rows}):
        rs = [r for r in rows if r["profile"] == p]
        c = Counter(r["final_verdict"] for r in rs)
        w(f"| {p} | {len(rs)} | {sum(1 for r in rs if not r['rules_passed'])} | "
          f"{c.get('BID', 0)} | {c.get('REVIEW', 0)} | {c.get('NO_BID', 0)} |")
    with open("eval/REPORT.md", "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
