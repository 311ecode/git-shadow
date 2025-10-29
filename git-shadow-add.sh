#!/bin/bash
set -e

# --- Configuration ---
SHADOW_BRANCH="shadow"
CONFIG_FILE=".git-shadow-config"
REMOTE="origin"

# --- Helper Functions ---
git_shadow_check_in_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: This command must be run inside a Git repository." >&2; exit 1; }
}

git_shadow_get_repo_root() {
    git rev-parse --show-toplevel
}

git_shadow_get_repo_url() {
    git config --get "remote.${REMOTE}.url"
}

# --- Main Logic ---
git_shadow_check_in_repo

if [ -z "$1" ]; then
    echo "Usage: git-shadow-add <path-to-file-or-dir>" >&2
    exit 1
fi

REPO_ROOT=$(git_shadow_get_repo_root)
# Get the relative path from the repo root, even if run from a subdir
FILE_PATH=$(realpath -s --relative-to="$REPO_ROOT" "$1")

# User Requirement: Only add files that are already ignored by the main branch
if ! git check-ignore -q "$FILE_PATH"; then
    echo "Error: '${FILE_PATH}' is not ignored by your main .gitignore." >&2
    echo "Please add it to your .gitignore first." >&2
    exit 1
fi

echo "Adding '${FILE_PATH}' to shadow config..."

TEMP_DIR=$(mktemp -d)
REPO_URL=$(git_shadow_get_repo_url)

# Clone the shadow branch
git clone --quiet --depth 1 --branch "${SHADOW_BRANCH}" "${REPO_URL}" "$TEMP_DIR"

CONFIG_PATH="${TEMP_DIR}/${CONFIG_FILE}"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Error: '${CONFIG_FILE}' not found in shadow branch." >&2
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Check if the path is already in the config
if grep -qFx "$FILE_PATH" "$CONFIG_PATH"; then
    echo "'${FILE_PATH}' is already in the shadow config. No changes made."
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Add the new path to the config
echo "${FILE_PATH}" >> "${CONFIG_PATH}"

# Commit and push the config change
(
    cd "$TEMP_DIR"
    git add "${CONFIG_FILE}"
    git commit -m "shadow: add '${FILE_PATH}' to config"
    git push "${REMOTE}" "${SHADOW_BRANCH}"
) >/dev/null

rm -rf "$TEMP_DIR"
echo "Successfully added '${FILE_PATH}' to shadow config."
echo "Run 'git-shadow-push' to upload the file's contents."
