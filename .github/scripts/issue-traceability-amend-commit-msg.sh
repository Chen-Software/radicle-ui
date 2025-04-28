#!/bin/bash
set -euo pipefail

# --- Safety Checks ---
if [ -z "${ISSUE_URL:-}" ]; then
  echo "::error::ISSUE_URL is required."
  exit 1
fi
if [ -z "${BASE_SHA:-}" ]; then
  echo "::error::BASE_SHA is required."
  exit 1
fi

# --- Check for and handle unstaged changes ---
echo "Checking for unstaged changes..."
if ! git diff --quiet; then
  echo "Unstaged changes detected. Stashing changes before proceeding..."
  git stash save "Temporary stash before filter-branch operation"
  CHANGES_STASHED=true
else
  echo "Working directory is clean."
  CHANGES_STASHED=false
fi

# --- Create temporary directory for filter script ---
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# --- Filter Logic --- 
# Create a temporary script to filter commit messages
cat > "$TEMP_DIR/filter_script.sh" << 'EOF'
#!/bin/bash

# Read the commit message from stdin and save it
ORIG_MSG=$(cat)
echo "$ORIG_MSG" > "$TEMP_DIR/original.msg"

# Define the issue link pattern
ISSUE_PATTERN='^- Issue: https://git\.chen\.so/sveltia-next-ts/i/[0-9a-f]{40}$'

# Extract all issue links from the original message
EXISTING_LINKS=$(echo "$ORIG_MSG" | grep -E "$ISSUE_PATTERN" || true)

# If there's a separator line, keep only the part before it
MSG_BODY=$(echo "$ORIG_MSG" | sed '/^---$/q' | sed '/^---$/d')

# Remove any issue links from the message body
CLEANED_MSG_BODY=$(echo "$MSG_BODY" | grep -v -E "$ISSUE_PATTERN" || true)

# Combine the new link with any existing links and deduplicate
FORMATTED_NEW_LINK="- Issue: $ISSUE_URL"
ALL_LINKS=$(echo -e "$FORMATTED_NEW_LINK\n$EXISTING_LINKS")
UNIQUE_LINKS=$(echo "$ALL_LINKS" | grep -v '^$' | sort -u)

# Construct the final message: cleaned body + separator + unique links
echo "$CLEANED_MSG_BODY"
echo -e "\n---\n"
echo "$UNIQUE_LINKS"
EOF

# Make the filter script executable
chmod +x "$TEMP_DIR/filter_script.sh"

# --- Apply the filter script to each commit ---
export ISSUE_URL TEMP_DIR
git filter-branch --force --msg-filter "$TEMP_DIR/filter_script.sh" "${BASE_SHA}..HEAD"

# --- Restore stashed changes if needed ---
if [ "$CHANGES_STASHED" = true ]; then
  echo "Restoring stashed changes..."
  git stash pop
fi

echo "Commit messages amended successfully."
