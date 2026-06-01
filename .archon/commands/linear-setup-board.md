## Linear — Setup Board (Mark In Progress)

Read `.spdd/meta.yml` → `linear_issue_id`.
Read `.spdd/config.yml` → `linear.api_key_env`, `linear.states.in_progress`,
`linear.labels.type_feature`, `linear.project_id`.

Uses **Python + PyYAML** for config parsing (robust to indentation/order) and
**jq** for GraphQL payload building (no manual JSON escape).

Execute:

```bash
# 1. Helper: read any dotted path from a YAML file
yget() {
  # usage: yget <file> <dotted.path>
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

# 2. Resolve API key (env var name from config)
KEY_VAR=$(yget .spdd/config.yml linear.api_key_env)
KEY=$(printenv "$KEY_VAR")
if [ -z "$KEY" ]; then
  echo "ABORT: $KEY_VAR env var not set. Run: export $KEY_VAR=lin_api_..."
  exit 1
fi

# 3. Read IDs from config + meta
ISSUE_ID=$(yget .spdd/meta.yml linear_issue_id)
STATE_ID=$(yget .spdd/config.yml linear.states.in_progress)
LABEL_ID=$(yget .spdd/config.yml linear.labels.type_feature)
PROJECT_ID=$(yget .spdd/config.yml linear.project_id)

# 4. Helper: POST a GraphQL mutation with single { issueId, value } variable
linear_issue_update() {
  # usage: linear_issue_update <field_name> <value>
  local var_name="$1"
  local var_value="$2"
  local payload
  if [ "$var_name" = "labelIds" ]; then
    payload=$(jq -nc --arg issueId "$ISSUE_ID" --arg v "$var_value" \
      '{query: "mutation($issueId:String!,$v:String!){issueUpdate(id:$issueId,input:{labelIds:[$v]}){success issue{identifier}}}",
        variables:{issueId:$issueId,v:$v}}')
  else
    payload=$(jq -nc --arg issueId "$ISSUE_ID" --arg v "$var_value" --arg key "$var_name" \
      '{query: ("mutation($issueId:String!,$v:String!){issueUpdate(id:$issueId,input:{" + $key + ":$v}){success issue{identifier state{name}}}}"),
        variables:{issueId:$issueId,v:$v}}')
  fi
  curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $KEY" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

# 5. State → In Progress
linear_issue_update stateId "$STATE_ID" \
  | grep -q '"success":true' && echo "Linear: state → In Progress ✓" || echo "Linear: state update failed (non-fatal)"

# 6. Label type:feature (skip placeholders / empty)
if [[ "$LABEL_ID" != *"{{"* ]] && [ -n "$LABEL_ID" ]; then
  linear_issue_update labelIds "$LABEL_ID" \
    | grep -q '"success":true' && echo "Linear: label type:feature added ✓" || echo "Linear: label update failed (non-fatal)"
fi

# 7. Project link (skip placeholders / empty)
if [[ "$PROJECT_ID" != *"{{"* ]] && [ -n "$PROJECT_ID" ]; then
  linear_issue_update projectId "$PROJECT_ID" \
    | grep -q '"success":true' && echo "Linear: added to project ✓" || echo "Linear: project update failed (non-fatal)"
fi

# 8. Persist item_id em meta.yml (backwards compat)
if [ -n "$ISSUE_ID" ]; then
  if grep -q '^item_id:' .spdd/meta.yml; then
    sed -i "s|^item_id:.*|item_id: \"$ISSUE_ID\"|" .spdd/meta.yml
  else
    echo "item_id: \"$ISSUE_ID\"" >> .spdd/meta.yml
  fi
fi
```

All steps non-fatal except API key resolution (step 2). Log each result to stdout.
