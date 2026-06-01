## Linear — Mark In Review

Read `.spdd/meta.yml` → `linear_issue_id`.
Read `.spdd/config.yml` → `linear.api_key_env`, `linear.states.in_review`.

Uses **Python + PyYAML** for config parsing (robust to indentation/order) and
**jq** for GraphQL payload building.

Execute:

```bash
# 1. Helper: read any dotted path from a YAML file
yget() {
  python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
for k in sys.argv[2].split('.'):
    d = d.get(k, '') if isinstance(d, dict) else ''
    if d == '':
        break
print(d if d is not None else '')
" "$1" "$2"
}

# 2. Resolve config values
KEY_VAR=$(yget .spdd/config.yml linear.api_key_env)
KEY=$(printenv "$KEY_VAR")
ISSUE_ID=$(yget .spdd/meta.yml linear_issue_id)
STATE_ID=$(yget .spdd/config.yml linear.states.in_review)

# Skip silently if any are missing/placeholder
if [ -z "$KEY" ] || [ -z "$ISSUE_ID" ] || [ -z "$STATE_ID" ] || [[ "$STATE_ID" == *"{{"* ]]; then
  echo "Linear: state update skipped (missing config)"
  exit 0
fi

# 3. Build GraphQL payload with variables (no manual escaping)
PAYLOAD=$(jq -nc \
  --arg issueId "$ISSUE_ID" \
  --arg stateId "$STATE_ID" \
  '{
    query: "mutation($issueId: String!, $stateId: String!) { issueUpdate(id: $issueId, input: { stateId: $stateId }) { success issue { identifier state { name } } } }",
    variables: { issueId: $issueId, stateId: $stateId }
  }')

# 4. POST
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  | grep -q '"success":true' && echo "Linear: state → In Review ✓" || echo "Linear: state update failed (non-fatal)"
```

Non-fatal — if the call fails, log and continue.
