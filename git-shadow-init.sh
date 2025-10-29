#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
SHADOW_BRANCH="shadow"
CONFIG_FILE=".git-shadow-config"
REMOTE="origin"

# --- Helper Functions ---
git_shadow_check_in_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: This command must be run inside a Git repository." >&2; exit 1; }
}

git_shadow_get_repo_url() {
    local url
    url=$(git config --get "remote.${REMOTE}.url")
    if [ -z "$url" ]; then
        echo "Error: Could not find remote URL for '${REMOTE}'." >&2
        echo "Please ensure your remote is set up." >&2
        exit 1
    fi
    echo "$url"
}

# --- Main Logic ---
git_shadow_check_in_repo
REPO_URL=$(git_shadow_get_repo_url)

echo "Checking for shadow branch '${SHADOW_BRANCH}' on remote '${REMOTE}'..."

# Check if the remote branch already exists
if git ls-remote --exit-code --heads "${REMOTE}" "${SHADOW_BRANCH}" >/dev/null 2>&1; then
    echo "Shadow branch '${SHADOW_BRANCH}' already exists on remote."
else
    echo "Shadow branch not found. Creating it..."
    
    # Create a temporary directory for a fresh repo
    TEMP_DIR=$(mktemp -d)
    
    # Initialize a new repo, create the orphan branch, and add the config
    (
        cd "$TEMP_DIR"
        git init -b "${SHADOW_BRANCH}" >/dev/null
        echo "# Git Shadow Config - Lists files/dirs to be tracked in this branch" > "${CONFIG_FILE}"
        git add "${CONFIG_FILE}"
        git commit -m "shadow: initialize shadow config" >/dev/null
        git remote add "${REMOTE}" "${REPO_URL}"
        git push -u "${REMOTE}" "${SHADOW_BRANCH}" >/dev/null
    )
    
    # Clean up
    rm -rf "$TEMP_DIR"
    echo "Successfully created and pushed new branch '${SHADOW_BRANCH}'."
fi

echo ""
echo "Initialization complete."
echo "Running an initial 'pull' to restore any existing shadow files..."

# Get the directory of the currently executing script
SCRIPT_DIR=$(dirname "$0")
# Call the pull script (assuming it's in the same directory)
if [ -f "${SCRIPT_DIR}/git-shadow-pull.sh" ]; then
    "${SCRIPT_DIR}/git-shadow-pull.sh"
else
    echo "Warning: 'git-shadow-pull.sh' not found. Skipping initial pull." >&2
    echo "Please run 'git-shadow-pull' manually." >&2
fi

echo ""
echo "Reminder: Use 'git-shadow-add <path>' to add ignored files to the shadow config."
