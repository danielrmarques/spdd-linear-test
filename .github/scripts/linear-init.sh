#!/usr/bin/env bash
# linear-init.sh — Interactive setup: queries Linear API → populates .spdd/config.yml
# Usage: bash .github/scripts/linear-init.sh
# Requires: curl, jq, LINEAR_API_KEY env var (or will prompt)

set -euo pipefail

CONFIG=".spdd/config.yml"
API="https://api.linear.app/graphql"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  Linear Init — SPDD project setup           │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo ""

# ── Check config file ─────────────────────────────────────────────────────────
if [ ! -f "$CONFIG" ]; then
  echo "ERROR: $CONFIG not found. Run from project root." >&2
  exit 1
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

# ── Test authentication ───────────────────────────────────────────────────────
echo "Testing authentication..."
AUTH=$(gql "query { viewer { name email } }")
if ! echo "$AUTH" | jq -e '.data.viewer.name' > /dev/null 2>&1; then
  echo "ERROR: Authentication failed. Check your LINEAR_API_KEY." >&2
  exit 1
fi
VIEWER=$(echo "$AUTH" | jq -r '.data.viewer.name')
echo -e "${GREEN}✓ Authenticated as: $VIEWER${NC}"
echo ""

# ── Select team ───────────────────────────────────────────────────────────────
echo "Fetching teams..."
TEAMS_RAW=$(gql "query { teams { nodes { id name key } } }")
TEAM_IDS=($(echo "$TEAMS_RAW" | jq -r '.data.teams.nodes[].id'))
TEAM_NAMES=($(echo "$TEAMS_RAW" | jq -r '.data.teams.nodes[].name'))
TEAM_KEYS=($(echo "$TEAMS_RAW" | jq -r '.data.teams.nodes[].key'))

echo ""
echo "Available teams:"
for i in "${!TEAM_IDS[@]}"; do
  echo "  $((i+1)). ${TEAM_KEYS[$i]} — ${TEAM_NAMES[$i]}"
done
echo ""
read -r -p "Select team number: " TEAM_NUM
TEAM_IDX=$((TEAM_NUM-1))
TEAM_ID="${TEAM_IDS[$TEAM_IDX]}"
TEAM_KEY="${TEAM_KEYS[$TEAM_IDX]}"
echo -e "${GREEN}✓ Team: $TEAM_KEY (${TEAM_ID})${NC}"
echo ""

# ── Map states ────────────────────────────────────────────────────────────────
echo "Fetching workflow states for team $TEAM_KEY..."
STATES_RAW=$(gql "query { team(id: \\\"$TEAM_ID\\\") { states { nodes { id name type } } } }")
STATE_IDS=($(echo "$STATES_RAW" | jq -r '.data.team.states.nodes[].id'))
STATE_NAMES=($(echo "$STATES_RAW" | jq -r '.data.team.states.nodes[].name'))
STATE_TYPES=($(echo "$STATES_RAW" | jq -r '.data.team.states.nodes[].type'))

declare -A STATE_MAP
for r in in_progress in_review done blocked; do
  echo ""
  echo "States available:"
  for i in "${!STATE_IDS[@]}"; do
    echo "  $((i+1)). ${STATE_NAMES[$i]} (${STATE_TYPES[$i]})"
  done
  read -r -p "Select state for '$r': " S_NUM
  S_IDX=$((S_NUM-1))
  STATE_MAP[$r]="${STATE_IDS[$S_IDX]}"
  echo -e "${GREEN}✓ $r → ${STATE_NAMES[$S_IDX]}${NC}"
done
echo ""

# ── Map labels ────────────────────────────────────────────────────────────────
echo "Fetching labels..."
LABELS_RAW=$(gql "query { issueLabels { nodes { id name } } }")
LABEL_IDS=($(echo "$LABELS_RAW" | jq -r '.data.issueLabels.nodes[].id'))
LABEL_NAMES=($(echo "$LABELS_RAW" | jq -r '.data.issueLabels.nodes[].name'))

echo ""
echo "Labels available:"
for i in "${!LABEL_IDS[@]}"; do
  echo "  $((i+1)). ${LABEL_NAMES[$i]}"
done

FEATURE_LABEL_ID=""
REVIEW_LABEL_ID=""

echo ""
read -r -p "Select label for 'type:feature' (0 to skip): " L_NUM
if [ "$L_NUM" != "0" ]; then
  L_IDX=$((L_NUM-1))
  FEATURE_LABEL_ID="${LABEL_IDS[$L_IDX]}"
  echo -e "${GREEN}✓ type:feature → ${LABEL_NAMES[$L_IDX]}${NC}"
fi

echo ""
read -r -p "Select label for 'review:pending' (0 to skip): " L_NUM
if [ "$L_NUM" != "0" ]; then
  L_IDX=$((L_NUM-1))
  REVIEW_LABEL_ID="${LABEL_IDS[$L_IDX]}"
  echo -e "${GREEN}✓ review:pending → ${LABEL_NAMES[$L_IDX]}${NC}"
fi

# ── Optional: select project ──────────────────────────────────────────────────
PROJECT_ID=""
echo ""
read -r -p "Add issues to a Linear Project? (y/N): " ADD_PROJECT
if [[ "$ADD_PROJECT" =~ ^[Yy]$ ]]; then
  echo "Fetching projects..."
  PROJECTS_RAW=$(gql "query { projects { nodes { id name } } }")
  PROJECT_IDS=($(echo "$PROJECTS_RAW" | jq -r '.data.projects.nodes[].id'))
  PROJECT_NAMES=($(echo "$PROJECTS_RAW" | jq -r '.data.projects.nodes[].name'))
  echo ""
  echo "Projects available:"
  for i in "${!PROJECT_IDS[@]}"; do
    echo "  $((i+1)). ${PROJECT_NAMES[$i]}"
  done
  read -r -p "Select project number (0 to skip): " P_NUM
  if [ "$P_NUM" != "0" ]; then
    P_IDX=$((P_NUM-1))
    PROJECT_ID="${PROJECT_IDS[$P_IDX]}"
    echo -e "${GREEN}✓ Project → ${PROJECT_NAMES[$P_IDX]}${NC}"
  fi
fi

# ── Write to config.yml ───────────────────────────────────────────────────────
echo ""
echo "Writing UUIDs to $CONFIG..."

sed_replace() {
  local key="$1"
  local val="$2"
  sed -i "s|\"{{$key}}\"|\"$val\"|g" "$CONFIG"
}

sed_replace "linear_team_id"           "$TEAM_ID"
sed_replace "linear_project_id"        "${PROJECT_ID:-{{linear_project_id}}}"
sed_replace "linear_state_in_progress" "${STATE_MAP[in_progress]}"
sed_replace "linear_state_in_review"   "${STATE_MAP[in_review]}"
sed_replace "linear_state_done"        "${STATE_MAP[done]}"
sed_replace "linear_state_blocked"     "${STATE_MAP[blocked]}"
sed_replace "linear_label_feature"     "${FEATURE_LABEL_ID:-{{linear_label_feature}}}"
sed_replace "linear_label_review"      "${REVIEW_LABEL_ID:-{{linear_label_review}}}"

echo -e "${GREEN}✓ $CONFIG updated${NC}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  Setup complete — next steps                │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
echo ""
echo "1. Set your API key permanently:"
echo "   echo 'export LINEAR_API_KEY=lin_api_...' >> ~/.bashrc"
echo ""
echo "2. Branch naming (auto-links to Linear on push):"
echo "   git checkout -b feat/${TEAM_KEY}-NNN-description"
echo ""
echo "3. PR magic words (auto-closes Linear issue on merge):"
echo "   Closes ${TEAM_KEY}-NNN"
echo ""
echo "4. Run a workflow:"
echo "   archon workflow run spdd-feature-exec \"${TEAM_KEY}-1\""
echo ""
echo "5. Enable Linear-GitHub integration at:"
echo "   https://linear.app/settings/integrations/github"
