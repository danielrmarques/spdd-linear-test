## Linear — Setup Board (Mark In Progress)

Read `.spdd/meta.yml` → get `linear_issue_id`.
Read `.spdd/config.yml` → get `linear.api_key_env`, `linear.states.in_progress`,
`linear.labels.type_feature`, `linear.project_id`.

Execute the following steps:

1. Resolve API key:
   ```bash
   KEY_VAR=$(grep 'api_key_env:' .spdd/config.yml | awk '{print $2}' | tr -d '"')
   KEY=$(printenv "$KEY_VAR")
   ```
   If KEY is empty, abort with: "LINEAR_API_KEY env var not set. Run: export LINEAR_API_KEY=lin_api_..."

2. Read values from config:
   ```bash
   ISSUE_ID=$(grep 'linear_issue_id:' .spdd/meta.yml | awk '{print $2}' | tr -d '"')
   STATE_ID=$(grep 'in_progress:' .spdd/config.yml | awk '{print $2}' | tr -d '"')
   LABEL_ID=$(grep 'type_feature:' .spdd/config.yml | awk '{print $2}' | tr -d '"')
   PROJECT_ID=$(grep 'project_id:' .spdd/config.yml | awk 'NR==1{print $2}' | tr -d '"')
   ```

3. Update issue state to In Progress:
   ```bash
   curl -s -X POST https://api.linear.app/graphql \
     -H "Authorization: $KEY" \
     -H "Content-Type: application/json" \
     -d "{\"query\": \"mutation { issueUpdate(id: \\\"$ISSUE_ID\\\", input: { stateId: \\\"$STATE_ID\\\" }) { success issue { identifier state { name } } } }\"}" \
     | grep -q '"success":true' && echo "Linear: state → In Progress ✓" || echo "Linear: state update failed (non-fatal)"
   ```

4. Add type:feature label (skip if LABEL_ID contains `{{`):
   ```bash
   if [[ "$LABEL_ID" != *"{{"* ]]; then
     curl -s -X POST https://api.linear.app/graphql \
       -H "Authorization: $KEY" \
       -H "Content-Type: application/json" \
       -d "{\"query\": \"mutation { issueUpdate(id: \\\"$ISSUE_ID\\\", input: { labelIds: [\\\"$LABEL_ID\\\"] }) { success } }\"}" \
       | grep -q '"success":true' && echo "Linear: label type:feature added ✓" || echo "Linear: label update failed (non-fatal)"
   fi
   ```

5. Add to project (skip if project_id contains `{{`):
   ```bash
   if [[ "$PROJECT_ID" != *"{{"* ]]; then
     curl -s -X POST https://api.linear.app/graphql \
       -H "Authorization: $KEY" \
       -H "Content-Type: application/json" \
       -d "{\"query\": \"mutation { issueUpdate(id: \\\"$ISSUE_ID\\\", input: { projectId: \\\"$PROJECT_ID\\\" }) { success } }\"}" \
       | grep -q '"success":true' && echo "Linear: added to project ✓" || echo "Linear: project update failed (non-fatal)"
   fi
   ```

6. Update `.spdd/meta.yml`: set `item_id: "$ISSUE_ID"` (kept for backwards compatibility).

All steps are non-fatal except step 1 (missing API key). Log each result to stdout.
