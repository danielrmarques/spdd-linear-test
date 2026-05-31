## Linear — Post Comment

Post $COMMENT_BODY as a comment on the Linear issue.

Read `.spdd/meta.yml` → get `linear_issue_id`.
Read `.spdd/config.yml` → get `linear.api_key_env`.

Execute:

1. Resolve API key and issue ID:
   ```bash
   KEY_VAR=$(grep 'api_key_env:' .spdd/config.yml | awk '{print $2}' | tr -d '"')
   KEY=$(printenv "$KEY_VAR")
   ISSUE_ID=$(grep 'linear_issue_id:' .spdd/meta.yml | awk '{print $2}' | tr -d '"')
   ```

2. Escape $COMMENT_BODY for JSON (replace `"` with `\"`, newlines with `\n`):
   ```bash
   ESCAPED=$(echo "$COMMENT_BODY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
   ```

3. Post comment:
   ```bash
   curl -s -X POST https://api.linear.app/graphql \
     -H "Authorization: $KEY" \
     -H "Content-Type: application/json" \
     -d "{\"query\": \"mutation { commentCreate(input: { issueId: \\\"$ISSUE_ID\\\", body: $ESCAPED }) { success comment { id } } }\"}" \
     | grep -q '"success":true' && echo "Linear: comment posted ✓" || echo "Linear: comment failed (non-fatal)"
   ```

Non-fatal — if comment fails, log and continue.
