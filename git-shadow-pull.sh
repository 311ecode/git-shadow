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

REPO_ROOT=$(git_shadow_get_repo_root)
REPO_URL=$(git_shadow_get_repo_url)
TEMP_DIR=$(mktemp -d)

echo "Cloning shadow branch to temporary directory..."
git clone --quiet --depth 1 --branch "${SHADOW_BRANCH}" "${REPO_URL}" "$TEMP_DIR"

CONFIG_PATH="${TEMP_DIR}/${CONFIG_FILE}"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Error: '${CONFIG_FILE}' not found in shadow branch." >&2
    echo "Run 'git-shadow-init' or 'git-shadow-add' first." >&2
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Syncing files from shadow branch to working directory..."

# Loop through each line in the config file
# Added protection for paths with spaces
while IFS= read -r file_path || [ -n "$file_path" ]; do
    if [ -z "$file_path" ]; then continue; fi # Skip empty lines
    if [[ "$file_path" == \#* ]]; then continue; fi # Skip comments

    SOURCE_PATH="${TEMP_DIR}/${file_path}"
    DEST_PATH="${REPO_ROOT}/${file_path}"

    if [ ! -e "${SOURCE_PATH}" ]; then
        echo "Warning: '${file_path}' listed in config but not found in shadow branch. Skipping." >&2
        continue
    fi

    # Ensure the destination directory exists in the main repo
    mkdir -p "$(dirname "${DEST_PATH}")"
    
    # Copy from the temp clone TO the main repo
    cp -r "${SOURCE_PATH}" "${DEST_PATH}"
    echo "  <- Restoring: ${file_path}"

done < <(grep -vE '^\s*#|^\s*$' "${CONFIG_PATH}") # Read file, skipping comments/empty lines

rm -rf "$TEMP_DIR"
echo "Shadow pull complete. Files are restored in your working directory."
