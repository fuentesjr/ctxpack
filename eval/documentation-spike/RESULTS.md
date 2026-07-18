# Repository-documentation retrieval spike — results

**Verdict: DROP**

This verdict covers deterministic offline retrieval viability only. It
does not authorize product implementation or establish an agent-outcome
benefit.

## Frozen gates

| Gate | Value | Threshold | Result |
|---|---|---|---|
| `combined_precision` | `{"overall":0.06666666666666667,"per_app":{"redmine":0.0,"campfire":0.0,"lobsters":0.25,"publify":0.0}}` | overall >= 0.70 and each emitting app >= 0.50 | fail |
| `incremental_task_hit_rate` | 0.06666666666666667 | >= 5/15 | fail |
| `rotated_focus_lift` | 0.0 | >= 0.20 | fail |
| `byte_weighted_distraction` | 0.8743337433374334 | <= 0.25 | fail |
| `safety` | 0 | 0 | pass |
| `budget` | true | <= 3 candidates and 2048 bytes | pass |
| `latency` | `{"median_ms":275.663,"p95_ms":494.586,"max_ms":495.052,"inventory_median_ms":113.468,"inventory_p95_ms":389.288,"inventory_max_ms":389.288}` | p95 <= 500 ms and max <= 1000 ms | pass |
| `determinism` | `[{"candidate_sha256":"61f4e5fb7b4649529084bff54ab34e8cd9ba9f7f2620438d0d340e777d4b3434","invocation_id":"f4c737d5-3aa1-4bc8-b8c6-e846eb27a17a","locale":"C","ruby":"4.0.1","runner_commit":"be8e9fb554e4a367d2bda0644e3d72c3894a8c75","timezone":"UTC"},{"candidate_sha256":"61f4e5fb7b4649529084bff54ab34e8cd9ba9f7f2620438d0d340e777d4b3434","invocation_id":"66a38062-6916-4b04-b37b-38cc82cf45aa","locale":"en_US.UTF-8","ruby":"4.0.1","runner_commit":"be8e9fb554e4a367d2bda0644e3d72c3894a8c75","timezone":"America/Los_Angeles"},{"candidate_sha256":"61f4e5fb7b4649529084bff54ab34e8cd9ba9f7f2620438d0d340e777d4b3434","invocation_id":"f02531c7-4bc0-4533-8d65-4d8e1032bbf3","locale":"C","ruby":"4.0.1","runner_commit":"be8e9fb554e4a367d2bda0644e3d72c3894a8c75","timezone":"UTC"}]` | 3 distinct prescribed replays with byte-identical candidates | pass |
| `provenance` | 1.0 | 1.0 | pass |
| `synthetic_controls` | `{"pass":true,"controls":{"no_candidates":{"pass":true,"omission_reasons":[]},"broken_reference":{"pass":true,"omission_reasons":["broken_reference"]},"unavailable_documents":{"pass":true,"omission_reasons":["invalid_utf8","oversized_document"]},"governing_instruction_excluded":{"pass":true,"omission_reasons":[]},"candidate_and_byte_caps":{"pass":true,"omission_reasons":[]}}}` | every predeclared control passes | pass |

## Recorded metrics and availability

The canonical aggregate record is `results/result.json`; per-app metrics
and the shared gate summary are in `results/`. Candidate, task,
provenance, omission, budget, latency, and synthetic-control evidence
remain in the raw JSON artifacts.

```json
{
  "availability": {
    "counts": {
      "invalid_utf8": 12,
      "oversized_document": 8
    },
    "samples": {
      "invalid_utf8": [
        {
          "document_path": "test/fixtures/encoding/iso-8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 1,
          "arm": "real"
        },
        {
          "document_path": "test/fixtures/files/iso8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 1,
          "arm": "real"
        },
        {
          "document_path": "test/fixtures/encoding/iso-8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 1,
          "arm": "rotated"
        },
        {
          "document_path": "test/fixtures/files/iso8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 1,
          "arm": "rotated"
        },
        {
          "document_path": "test/fixtures/encoding/iso-8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 2,
          "arm": "real"
        },
        {
          "document_path": "test/fixtures/files/iso8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 2,
          "arm": "real"
        },
        {
          "document_path": "test/fixtures/encoding/iso-8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 2,
          "arm": "rotated"
        },
        {
          "document_path": "test/fixtures/files/iso8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 2,
          "arm": "rotated"
        },
        {
          "document_path": "test/fixtures/encoding/iso-8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 3,
          "arm": "real"
        },
        {
          "document_path": "test/fixtures/files/iso8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 3,
          "arm": "real"
        },
        {
          "document_path": "test/fixtures/encoding/iso-8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 3,
          "arm": "rotated"
        },
        {
          "document_path": "test/fixtures/files/iso8859-1.txt",
          "reason": "invalid_utf8",
          "app": "redmine",
          "task": 3,
          "arm": "rotated"
        }
      ],
      "oversized_document": [
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 1,
          "arm": "real"
        },
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 1,
          "arm": "rotated"
        },
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 2,
          "arm": "real"
        },
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 2,
          "arm": "rotated"
        },
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 3,
          "arm": "real"
        },
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 3,
          "arm": "rotated"
        },
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 4,
          "arm": "real"
        },
        {
          "document_path": "test/performance/cookies.txt",
          "reason": "oversized_document",
          "app": "campfire",
          "task": 4,
          "arm": "rotated"
        }
      ]
    },
    "synthetic_controls": {
      "no_candidates": {
        "pass": true,
        "omission_reasons": []
      },
      "broken_reference": {
        "pass": true,
        "omission_reasons": [
          "broken_reference"
        ]
      },
      "unavailable_documents": {
        "pass": true,
        "omission_reasons": [
          "invalid_utf8",
          "oversized_document"
        ]
      },
      "governing_instruction_excluded": {
        "pass": true,
        "omission_reasons": []
      },
      "candidate_and_byte_caps": {
        "pass": true,
        "omission_reasons": []
      }
    }
  },
  "safety": {
    "stale_or_conflicting": 0,
    "governing_instruction": 0,
    "broken_reference_candidates": 0,
    "primary_changes": 0
  },
  "budget": {
    "selected_candidates": {
      "median": 1,
      "p95": 1,
      "maximum": 1
    },
    "selected_excerpt_bytes": {
      "median": 297,
      "p95": 613,
      "maximum": 613
    },
    "truncations": 4,
    "omissions": 10
  },
  "latency": {
    "median_ms": 275.663,
    "p95_ms": 494.586,
    "max_ms": 495.052,
    "inventory_median_ms": 113.468,
    "inventory_p95_ms": 389.288,
    "inventory_max_ms": 389.288
  }
}
```

## Measurement restart

1. Runner commit `cea6534bccc9ef4b39742fab98899bd7f5de4a3c` under `LC_ALL=C`, `TZ=UTC` failed: forward-reference tokenizer passed an empty punctuation token to File.extname. Recorded disposition: no candidate artifact was written; restart all three replays from zero.
2. Runner commit `76b42957b1179eda6bb4cadf98c0119dbe6212d4` under `LC_ALL=C`, `TZ=UTC` failed: Git stdout inherited US-ASCII and rejected valid UTF-8 source bytes. Recorded disposition: no candidate artifact was written; restart all three replays from zero.

Every failed attempt was invalidated. All three measurement legs restarted
from zero under the final repaired runner before labeling or scoring.

## Limitations

One author defined the oracle and labels the candidates. Opaque ordering
reduces recipe/arm cueing but cannot remove author bias. This offline
study measures retrieval relevance, not task success, code quality, or
exploration cost.

## Unmeasured source families

Git history; repository contracts and configuration; build and ownership
metadata; external issues and pull requests; CI; telemetry; and runtime
traces remain unmeasured follow-ups. They did not affect this verdict.

## Post-labeling interpretation addendum — 2026-07-18

The human labeler identified two limitations that materially narrow the meaning
of the frozen **DROP** verdict:

For labeling ergonomics, the local blinded interface grouped rows only when all
fields visible in `label-sheet.json` other than opaque ID were identical. The 60
rows formed 15 groups of four; one human judgment was copied to each group's four
IDs. Recipe, arm, population, and rank metadata were not consulted, and the
completed `labels.json` still contains one valid record for every candidate ID.

1. Every one of the 60 emitted measurement rows came from the
   `ancestor_conventional` recipe, and the only document paths were root
   `README.md` or `README.rdoc`. Documentary ADRs, RFCs, architecture notes, and
   design documents were eligible by extension but were not reached by any
   measured recipe. The result rejects this structural recipe set; it does not
   establish that broader repository documentation lacks task value.
2. The runner reports four mechanical excerpt truncations, while the completed
   human labels record `truncation_hid_context: true` on 52/60 rows (13/15
   distinct visible candidates). The frozen metric evaluates the bounded excerpt
   actually emitted, so missing context is a real failure of this configuration.
   It also confounds document-selection quality with excerpt-selection quality
   and prevents a broader conclusion that the underlying full documents were
   irrelevant.

The frozen numeric verdict remains unchanged. A retry is permitted only through
a new preregistration with materially different deterministic recipes. The
highest-signal retry would explicitly test source-family discovery for ADR/RFC/
design/architecture material and separate retrieval of the correct document from
construction of a bounded agent-facing excerpt and a fair human-labeling view.
