#!/bin/bash
set -euo pipefail

# --- Environment Variables ---
# RADICLE_SITES and RADICLE_URLS as JSON arrays for multi-site support
RADICLE_SITES=${RADICLE_SITES:-'["git.chen.so", "code.chen.so", "git.chen.software", "code.chen.software"]'}
RADICLE_URLS=${RADICLE_URLS:-'["https://git.chen.so", "https://code.chen.so", "https://git.chen.software", "https://code.chen.software"]'}

# Determine primary site and URL for legacy compatibility
if [ ! -z "$RADICLE_SITES" ]; then
  readarray -t SITES < <(echo "$RADICLE_SITES" | jq -r '.[]')
  RADICLE_SITE="${SITES[0]}"
fi
if [ ! -z "$RADICLE_URLS" ]; then
  readarray -t URLS < <(echo "$RADICLE_URLS" | jq -r '.[]')
  RADICLE_URL="${URLS[0]}"
fi

# Use RADICLE_URL as primary URL for links
PRIMARY_URL="$RADICLE_URL"

# --- Input Validation ---
if [ $# -ne 5 ]; then
  echo "::error::Usage: $0 <total_commits> <issue_commits> <repo_name> <pr_total_commits> <pr_issue_commits>" >&2
  exit 1
fi

# Validate numeric inputs
for i in {1,2,4,5}; do
  if ! [[ "${!i}" =~ ^[0-9]+$ ]]; then
    echo "::error::Parameter $i must be a number" >&2
    exit 1
  fi
done

total_commits=$1
issue_commits=$2
repo_name=$3
pr_total_commits=$4
pr_issue_commits=$5

# --- Calculation ---
calculate_percentage() {
  local ic=$1
  local tc=$2
  awk -v ic="$ic" -v tc="$tc" 'BEGIN { if (tc > 0) { printf "%.2f", (ic/tc)*100 } else { print "0.00" } }'
}

percentage=$(calculate_percentage "$issue_commits" "$total_commits")
pr_percentage=$(calculate_percentage "$pr_issue_commits" "$pr_total_commits")

# --- Determine Badge Color ---
get_badge_color() {
  local percentage=$1
  if (( $(echo "$percentage >= 90" | bc -l) )); then
    echo "4c1" # bright green
  elif (( $(echo "$percentage >= 75" | bc -l) )); then
    echo "97CA00" # green
  elif (( $(echo "$percentage >= 50" | bc -l) )); then
    echo "dfb317" # yellow
  elif (( $(echo "$percentage >= 25" | bc -l) )); then
    echo "fe7d37" # orange
  else
    echo "e05d44" # red
  fi
}

color=$(get_badge_color "$percentage")

# --- Construct Badge URL ---
badge_url="https://img.shields.io/badge/issues-${percentage}%25-${color}"

# --- Generate Report Output --- 
cat << EOM
# Issue Traceability Report 

![Issue Traceability](${badge_url})

Total commits: $issue_commits out of $total_commits commits ($percentage%) reference an [issue](${PRIMARY_URL}/${repo_name}/issues).
- Current PR commits: $pr_issue_commits out of $pr_total_commits commits ($pr_percentage%) reference an [issue](${PRIMARY_URL}/${repo_name}/issues).
EOM
