#!/usr/bin/env bash
# linear-init.sh — Setup: queries Linear API → populates .spdd/config.yml.
#
# REGRA: cada novo repositório recebe um Linear Project NOVO (1:1 com o repo),
# pra permitir tracking e evolução isolados por projeto. O script cria o
# Project automaticamente usando o nome do repo (ou --name override).
#
# Usage:
#   bash .github/scripts/linear-init.sh
#   bash .github/scripts/linear-init.sh --name "my-custom-name"
#   bash .github/scripts/linear-init.sh --reuse-project <project_id>   # excepcional
#
# Idempotent: se .spdd/config.yml já tem linear_project_id real, não cria
# de novo — apenas confirma e segue.
#
# Requires: curl, jq, LINEAR_API_KEY env var (ou será solicitado interativamente).

set -euo pipefail

CONFIG=".spdd/config.yml"
API="https://api.linear.app/graphql"

# ── Args ──────────────────────────────────────────────────────────────────────
PROJECT_NAME_OVERRIDE=""
REUSE_PROJECT_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      PROJECT_NAME_OVERRIDE="$2"; shift 2;;
    --reuse-project)
      REUSE_PROJECT_ID="$2"; shift 2;;
    -h|--help)
      sed -n '2,15p' "$0"; exit 0;;
    *)
      echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  Linear Init — SPDD project setup           │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo ""

# ── Check config file ─────────────────────────────────────────────────────────
if [ ! -f "$CONFIG" ]; then
  echo -e "${RED}ERROR: $CONFIG not found. Run from project root.${NC}" >&2
  exit 1
fi

# ── Idempotency: skip if config already has real project_id ──────────────────
if grep -q "^[[:space:]]*project_id:[[:space:]]*\"[A-Za-z0-9_-]*\"" "$CONFIG" 2>/dev/null \
   && ! grep -q "{{linear_project_id}}" "$CONFIG"; then
  existing=$(grep "^[[:space:]]*project_id:" "$CONFIG" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
  echo -e "${YELLOW}WARN: $CONFIG already has linear_project_id=$existing${NC}"
  echo -e "${YELLOW}Skipping creation. Re-run após editar config.yml se quiser refazer.${NC}"
  exit 0
fi

# ── Resolve API key ───────────────────────────────────────────────────────────
if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo -e "${YELLOW}LINEAR_API_KEY not set.${NC}"
  read -r -p "Enter your Linear API key (lin_api_...): " LINEAR_API_KEY
fi

gql() {
  local query="$1"
  curl -s -X POST "$API" \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$query\"}"
}

gql_mut() {
  # gql_mut <query_with_double_quotes> — for mutations with embedded strings
  local query="$1"
  curl -s -X POST "$API" \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$query" '{query: $q}')"
}

# ── Test authentication ───────────────────────────────────────────────────────
echo "Testing authentication..."
AUTH=$(gql "query { viewer { name email } }")
if ! echo "$AUTH" | jq -e '.data.viewer.name' > /dev/null 2>&1; then
  echo -e "${RED}ERROR: Authentication failed. Check your LINEAR_API_KEY.${NC}" >&2
  echo "$AUTH" >&2
  exit 1
fi
VIEWER=$(echo "$AUTH" | jq -r '.data.viewer.name')
echo -e "${GREEN}✓ Authenticated as: $VIEWER${NC}"
echo ""

# ── Resolve repo name (for project name default) ─────────────────────────────
if [ -n "$PROJECT_NAME_OVERRIDE" ]; then
  PROJECT_NAME="$PROJECT_NAME_OVERRIDE"
elif git rev-parse --show-toplevel > /dev/null 2>&1; then
  PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
else
  PROJECT_NAME=$(basename "$(pwd)")
fi
echo -e "${CYAN}Project name (will be created in Linear): ${PROJECT_NAME}${NC}"
echo ""

# ── Select team ───────────────────────────────────────────────────────────────
echo "Fetching teams..."
TEAMS_RAW=$(gql "query { teams { nodes { id name key } } }")
# mapfile preserves whole lines (handles names with spaces).
mapfile -t TEAM_IDS   < <(echo "$TEAMS_RAW" | jq -r '.data.teams.nodes[].id')
mapfile -t TEAM_NAMES < <(echo "$TEAMS_RAW" | jq -r '.data.teams.nodes[].name')
mapfile -t TEAM_KEYS  < <(echo "$TEAMS_RAW" | jq -r '.data.teams.nodes[].key')

if [ ${#TEAM_IDS[@]} -eq 0 ]; then
  echo -e "${RED}ERROR: No teams found. Create a team in Linear first.${NC}" >&2
  exit 1
fi

echo ""
echo "Available teams:"
for i in "${!TEAM_IDS[@]}"; do
  echo "  $((i+1)). ${TEAM_KEYS[$i]} — ${TEAM_NAMES[$i]}"
done

if [ ${#TEAM_IDS[@]} -eq 1 ]; then
  TEAM_IDX=0
  echo -e "${GREEN}✓ Único team disponível, selecionado automaticamente.${NC}"
else
  echo ""
  read -r -p "Select team number: " TEAM_NUM
  TEAM_IDX=$((TEAM_NUM-1))
fi
TEAM_ID="${TEAM_IDS[$TEAM_IDX]}"
TEAM_KEY="${TEAM_KEYS[$TEAM_IDX]}"
echo -e "${GREEN}✓ Team: $TEAM_KEY (${TEAM_ID})${NC}"
echo ""

# ── Create OR reuse Linear Project ────────────────────────────────────────────
PROJECT_ID=""
if [ -n "$REUSE_PROJECT_ID" ]; then
  echo -e "${YELLOW}Using --reuse-project $REUSE_PROJECT_ID (skipping create).${NC}"
  PROJECT_ID="$REUSE_PROJECT_ID"
else
  echo "Creating Linear Project '${PROJECT_NAME}' under team ${TEAM_KEY}..."
  # GraphQL mutation. We use jq -nc to safely build the JSON body so the name
  # is properly escaped even if it contains quotes/special chars.
  MUT_BODY=$(jq -nc \
    --arg name "$PROJECT_NAME" \
    --arg team "$TEAM_ID" \
    --arg desc "Linked to repo: ${PROJECT_NAME}" \
    '{query: "mutation($name:String!,$team:String!,$desc:String!){projectCreate(input:{name:$name,teamIds:[$team],description:$desc}){success project{id name url}}}", variables: {name:$name, team:$team, desc:$desc}}')
  CREATE_RESP=$(curl -s -X POST "$API" \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$MUT_BODY")
  if ! echo "$CREATE_RESP" | jq -e '.data.projectCreate.success' > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Failed to create project.${NC}" >&2
    echo "$CREATE_RESP" >&2
    exit 1
  fi
  PROJECT_ID=$(echo "$CREATE_RESP" | jq -r '.data.projectCreate.project.id')
  PROJECT_URL=$(echo "$CREATE_RESP" | jq -r '.data.projectCreate.project.url')
  echo -e "${GREEN}✓ Project created: ${PROJECT_NAME}${NC}"
  echo -e "${GREEN}  ID: ${PROJECT_ID}${NC}"
  echo -e "${GREEN}  URL: ${PROJECT_URL}${NC}"
fi
echo ""

# ── Map states ────────────────────────────────────────────────────────────────
echo "Fetching workflow states for team $TEAM_KEY..."
STATES_RAW=$(gql "query { team(id: \\\"$TEAM_ID\\\") { states { nodes { id name type } } } }")
# mapfile preserves names like "In Progress" intact (no word splitting).
mapfile -t STATE_IDS   < <(echo "$STATES_RAW" | jq -r '.data.team.states.nodes[].id')
mapfile -t STATE_NAMES < <(echo "$STATES_RAW" | jq -r '.data.team.states.nodes[].name')
mapfile -t STATE_TYPES < <(echo "$STATES_RAW" | jq -r '.data.team.states.nodes[].type')

declare -A STATE_MAP

# Heuristic auto-pick (override interactively if user wants):
# - in_progress: type=started, name match "In Progress" (case-insensitive)
# - in_review:   type=started, name match "In Review"
# - done:        type=completed
# - blocked:     type=started, name match "Block"
auto_pick() {
  local role="$1"
  local name_pattern="$2"
  local type_filter="$3"
  for i in "${!STATE_IDS[@]}"; do
    n_lower=$(echo "${STATE_NAMES[$i]}" | tr '[:upper:]' '[:lower:]')
    if [[ "$n_lower" == *"$name_pattern"* ]] && [[ -z "$type_filter" || "${STATE_TYPES[$i]}" == "$type_filter" ]]; then
      STATE_MAP[$role]="${STATE_IDS[$i]}"
      echo -e "${GREEN}  $role → ${STATE_NAMES[$i]} (auto)${NC}"
      return 0
    fi
  done
  return 1
}

echo ""
echo "Auto-mapping workflow states..."
auto_pick in_progress "in progress" "started" || true
auto_pick in_review   "in review"   "started" || true
auto_pick done        ""            "completed" || true
auto_pick blocked     "block"       "started" || true

# For any role NOT auto-picked, prompt interactively
for r in in_progress in_review done blocked; do
  if [ -z "${STATE_MAP[$r]:-}" ]; then
    echo ""
    echo -e "${YELLOW}'$r' não auto-detectado.${NC} Selecione manualmente:"
    for i in "${!STATE_IDS[@]}"; do
      echo "  $((i+1)). ${STATE_NAMES[$i]} (${STATE_TYPES[$i]})"
    done
    read -r -p "Select state for '$r' (0 to skip): " S_NUM
    if [ "$S_NUM" != "0" ]; then
      S_IDX=$((S_NUM-1))
      STATE_MAP[$r]="${STATE_IDS[$S_IDX]}"
      echo -e "${GREEN}  $r → ${STATE_NAMES[$S_IDX]}${NC}"
    fi
  fi
done
echo ""

# ── Map labels (best-effort auto-pick by name) ───────────────────────────────
echo "Fetching labels..."
LABELS_RAW=$(gql "query { issueLabels { nodes { id name } } }")
mapfile -t LABEL_IDS   < <(echo "$LABELS_RAW" | jq -r '.data.issueLabels.nodes[].id')
mapfile -t LABEL_NAMES < <(echo "$LABELS_RAW" | jq -r '.data.issueLabels.nodes[].name')

FEATURE_LABEL_ID=""
REVIEW_LABEL_ID=""
for i in "${!LABEL_IDS[@]}"; do
  n_lower=$(echo "${LABEL_NAMES[$i]}" | tr '[:upper:]' '[:lower:]')
  if [ -z "$FEATURE_LABEL_ID" ] && [[ "$n_lower" == *"feature"* ]]; then
    FEATURE_LABEL_ID="${LABEL_IDS[$i]}"
    echo -e "${GREEN}✓ type:feature → ${LABEL_NAMES[$i]} (auto)${NC}"
  fi
  if [ -z "$REVIEW_LABEL_ID" ] && [[ "$n_lower" == *"review"* ]]; then
    REVIEW_LABEL_ID="${LABEL_IDS[$i]}"
    echo -e "${GREEN}✓ review:pending → ${LABEL_NAMES[$i]} (auto)${NC}"
  fi
done

# ── Write to config.yml ───────────────────────────────────────────────────────
echo ""
echo "Writing UUIDs to $CONFIG..."

sed_replace() {
  local key="$1"
  local val="$2"
  sed -i.bak "s|\"{{$key}}\"|\"$val\"|g" "$CONFIG"
}

sed_replace "linear_team_id"           "$TEAM_ID"
sed_replace "linear_project_id"        "$PROJECT_ID"
sed_replace "linear_state_in_progress" "${STATE_MAP[in_progress]:-}"
sed_replace "linear_state_in_review"   "${STATE_MAP[in_review]:-}"
sed_replace "linear_state_done"        "${STATE_MAP[done]:-}"
sed_replace "linear_state_blocked"     "${STATE_MAP[blocked]:-}"
sed_replace "linear_label_feature"     "${FEATURE_LABEL_ID:-}"
sed_replace "linear_label_review"      "${REVIEW_LABEL_ID:-}"

rm -f "${CONFIG}.bak"
echo -e "${GREEN}✓ $CONFIG updated${NC}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  Setup complete — next steps                │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo ""
echo "Linear Project: ${PROJECT_NAME}"
echo "Linear Project ID: ${PROJECT_ID}"
echo "Linear Team: ${TEAM_KEY}"
echo ""
echo "1. Persist API key (already set if rodando via VPS systemd/run-with-secrets):"
echo "   echo 'export LINEAR_API_KEY=lin_api_...' >> ~/.bashrc"
echo ""
echo "2. Branch naming (auto-links to Linear on push):"
echo "   git checkout -b feat/${TEAM_KEY}-NNN-description"
echo ""
echo "3. PR magic words (auto-closes Linear issue on merge):"
echo "   Closes ${TEAM_KEY}-NNN"
echo ""
echo "4. Run a workflow (create a Linear issue first, then):"
echo "   archon workflow run spdd-feature-exec \"${TEAM_KEY}-1\""
echo ""
echo "5. Linear-GitHub integration: https://linear.app/settings/integrations/github"
