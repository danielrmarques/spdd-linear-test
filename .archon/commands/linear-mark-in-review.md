## Linear — Mark In Review

Read `.spdd/meta.yml` → get `linear_issue_id`.
Read `.spdd/config.yml` → get `linear.api_key_env`, `linear.states.in_review`.

Execute:

1. Resolve API key and state ID:
   ```bash
   KEY_VAR=$(grep 'api_key_env:' .spdd/config.yml | awk '{print $2}' | tr -d '"')
   KEY=$(printenv "$KEY_VAR")
   ISSUE_ID=$(grep 'linear_issue_id:' .spdd/meta.yml | awk '{print $2}' | tr -d '"')
   STATE_ID=$(grep 'in_review:' .spdd/config.yml | awk '{print $2}' | tr -d '"')
   ```

2. Update issue state to In Review:
   ```bash
   curl -s -X POST https://api.linear.app/graphql \
     -H "Authorization: $KEY" \
     -H "Content-Type: application/json" \
     -d "{\"query\": \"mutation { issueUpdate(id: \\\"$ISSUE_ID\\\", input: { stateId: \\\"$STATE_ID\\\" }) { success issue { identifier state { name } } } }\"}" \
     | grep -q '"success":true' && echo "Linear: state → In Review ✓" || echo "Linear: state update failed (non-fatal)"
   ```

Non-fatal if STATE_ID contains `{{` (not configured) — skip silently.
