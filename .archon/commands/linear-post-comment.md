## Linear — Post Comment

Post `$COMMENT_BODY` as a comment on the Linear issue.

Read `.spdd/meta.yml` → `linear_issue_id`.
Read `.spdd/config.yml` → `linear.api_key_env`.

Uses **Python + PyYAML** for config parsing and **jq** for GraphQL variable
binding (no manual JSON escape — see incident in AILM-10 run where embedded
quotes broke the query).

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

# 2. Resolve API key and issue ID
KEY_VAR=$(yget .spdd/config.yml linear.api_key_env)
KEY=$(printenv "$KEY_VAR")
ISSUE_ID=$(yget .spdd/meta.yml linear_issue_id)

if [ -z "$KEY" ] || [ -z "$ISSUE_ID" ]; then
  echo "Linear: comment skipped (missing $KEY_VAR or linear_issue_id)"
  exit 0
fi

# 3. Build JSON payload with proper variable binding — no manual escaping
PAYLOAD=$(jq -nc \
  --arg issueId "$ISSUE_ID" \
  --arg body    "$COMMENT_BODY" \
  '{
    query: "mutation($issueId: String!, $body: String!) { commentCreate(input: { issueId: $issueId, body: $body }) { success comment { id } } }",
    variables: { issueId: $issueId, body: $body }
  }')

# 4. POST and check success
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  | grep -q '"success":true' && echo "Linear: comment posted ✓" || echo "Linear: comment failed (non-fatal)"
```

Non-fatal — if the call fails, log and continue.
