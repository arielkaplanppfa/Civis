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

- **Core pipeline**: [test script](https://platform.civisanalytics.com/spa/#/scripts/python3/347646218) fetches scripts from API and pushes to GitHub from Civis. Working.
- **PII safety**: nothing enters the repo without passing the scanner or human approval.
  - Regex scanner catches emails, phones, SSNs, SF case IDs (context-aware to reduce false positives)
    - Tested on 938 SQL scripts: 22 flagged (2.3%), all routed to human review
  - NER (presidio/spaCy) planned for names and addresses
  - False negative investigation in progress
  - Gating workflow (flagging, human review, approval) still needs testing

## Open Questions

1. Does the overall approach make sense?
2. Are we ok with the regex PII scanner? If we account for names, do we have data to test on?
3. Do we only mirror scripts active in the last year?
4. Where in the repo (branch? main?)?
5. Each sync overwrites the repo with current state (no git history of past syncs). Ok?
6. Daily v weekly schedule?

## Civis API Quirks

- **Pagination cap**: `client.scripts.list()` maxes out at 300 pages x 50 = 15,000 results, then returns a 500 error (not an empty list)
  - Workaround: query with `order="created_at"` using both `order_dir="asc"` and `"desc"` to get up to 30k per query
- **Type filter mismatch**: `.type` field on results returns capitalized names (`SQL`, `Python`, `Container`, `Custom`) but the `type` filter param expects lowercase (`sql`, `python3`, `containers`)
- **Custom scripts unfilterable**: `Custom` is not a valid `type` filter value -- these ~12,500+ scripts only appear in unfiltered listings
- **Category filter broken**: `category` param returns 15k for `script` and 0 for `import`/`export`/`enhancement`
- **No SSH in containers**: git push must use HTTPS + PAT
- **Credentials not readable via API**: `credentials.get()` doesn't return password -- must inject as script parameter (env var)

## Appendix: Code Snippets

### List all scripts by type (handles pagination cap)
```python
import civis

client = civis.APIClient()

# For types under 15k
for s in client.scripts.list(type="python3", iterator=True, limit=50):
    print(s.id, s.name, s.type)

# For types over 15k (sql, containers): union asc + desc
ids = set()
for order_dir in ["asc", "desc"]:
    try:
        for s in client.scripts.list(type="sql", iterator=True, limit=50,
                                     order="created_at", order_dir=order_dir):
            ids.add(s.id)
    except:
        pass  # 500 error at end of pagination
print(f"sql: {len(ids)} unique")
```

### Fetch script source code
```python
# SQL
full = client.scripts.get_sql(script_id)
source = full.sql

# Python
full = client.scripts.get_python3(script_id)
source = full.source

# Container (usually empty -- config in arguments/params)
full = client.scripts.get_containers(script_id)
source = full.docker_command  # typically empty for template-based scripts
config = full.arguments       # the useful part
```

### Fetch workflow definition
```python
full = client.workflows.get(workflow_id)
definition_yaml = full.definition
```

### PII regex scanner
```python
import re

PII_PATTERNS = {
    'EMAIL': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    'PHONE': r'\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b',
    'SSN': r'\b\d{3}-\d{2}-\d{4}\b',
    'SF_CASE_ID': r'\b0[23]\d{6}\b',
}
ID_CONTEXT = re.compile(r'\w*(?:_id|_key|_code)\b', re.IGNORECASE)

def scan_pii(content):
    hits = {}
    for label, pattern in PII_PATTERNS.items():
        for m in re.finditer(pattern, content):
            if label == 'PHONE':
                prefix = content[max(0, m.start()-80):m.start()]
                suffix = content[m.end():m.end()+50]
                if ID_CONTEXT.search(prefix) or re.match(
                    r'^\s*(?:\'?\s*(?:,|as)\s+\w*(?:id|key|code)\b)',
                    suffix, re.IGNORECASE
                ):
                    continue
            hits.setdefault(label, []).append(m.group())
    return hits
```

### Git push from Civis container script
```python
import subprocess
import os

token = os.environ["GITHUB_PAT_PASSWORD"]  # injected via Civis credential param
repo = "your-org/your-repo"
branch = "civis-backup-test"
work_dir = "/tmp/civis-backup"

subprocess.run(["git", "clone", f"https://{token}@github.com/{repo}.git", work_dir])
subprocess.run(["git", "checkout", branch], cwd=work_dir)
subprocess.run(["git", "config", "user.email", "civis-backup@noreply.ppfa.org"], cwd=work_dir)
subprocess.run(["git", "config", "user.name", "Civis Backup Bot"], cwd=work_dir)

# ... write files ...

subprocess.run(["git", "add", "-A"], cwd=work_dir)
subprocess.run(["git", "commit", "-m", "sync from civis"], cwd=work_dir)
subprocess.run(["git", "push", "origin", branch], cwd=work_dir)
```
