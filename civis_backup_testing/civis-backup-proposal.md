# Civis Backup: One-Way Sync to Git

## Why

Civis has no full-text search across scripts, no version history, and no way to see dependencies or data flow at a glance. A Git mirror gives us grep, diffs, workflow mapping, and AI tooling over the full codebase.

## What

Daily automated sync: Civis API -> PII scan -> private GitHub repo.

| Asset Type | Count | Stored |
|-----------|-------|--------|
| SQL | ~26,000 | Source + metadata |
| Python | ~8,900 | Source + metadata |
| Containers | ~17,900 | Config only (arguments, params, schedule) |
| Workflows | 513 | DAG definitions |
| JS/R/dbt | ~170 | Source + metadata |

Incremental after initial backfill. First run: ~30 min (last 2 yrs) to ~2.2 hrs (all time).

**Recommendation**: start with scripts active in the last year (~4,500 SQL + ~3,700 Python), expand to older scripts later if needed.

## Testing

**Nothing enters the repo without passing the PII scanner or human approval.**

- Regex scanner catches emails, phones, SSNs, SF case IDs (context-aware to reduce false positives)
  - Tested on 938 SQL scripts: 22 flagged (2.3%), all routed to human review
- NER (presidio/spaCy) planned for names and addresses
- False negative investigation in progress

## Next Steps

1. Finalize PII scanner (NER + false negative testing)
2. Stakeholder sign-off on PII approach
3. Build + deploy sync script
4. Initial backfill + review flagged scripts
5. Daily schedule
