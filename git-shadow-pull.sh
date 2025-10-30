git-shadow-pull() {
    # --- Configuration ---
    local GIT_SHADOW_BRANCH="shadow"
    local GIT_SHADOW_CONFIG_FILE=".git-shadow-config"
    local GIT_SHADOW_REMOTE="origin"

    # --- Helper Functions ---
    git_shadow_check_in_repo() {
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: This command must be run inside a Git repository." >&2; return 1; }
    }

    git_shadow_get_repo_root() {
        git rev-parse --show-toplevel
    }

    git_shadow_get_repo_url() {
        git config --get "remote.${GIT_SHADOW_REMOTE}.url"
    }

    # --- Main Logic ---
    local REPO_ROOT
    local REPO_URL
    local TEMP_DIR
    local relative_path
    local SOURCE_PATH
    local DEST_PATH

    git_shadow_check_in_repo || return 1

    REPO_ROOT=$(git_shadow_get_repo_root)
    REPO_URL=$(git_shadow_get_repo_url)
    TEMP_DIR=$(mktemp -d)

    echo "Cloning shadow branch to temporary directory..."
    git clone --quiet --depth 1 --branch "${GIT_SHADOW_BRANCH}" "${REPO_URL}" "$TEMP_DIR"

    echo "Syncing all files from shadow branch to working directory..."

    # Find ALL files/dirs in the temp clone, except .git and the config file
    # CRITICAL FIX: Use -type f to only get FILES, not directories
    (
        cd "$TEMP_DIR"
        find . -mindepth 1 -type f -not -path "./.git/*" -not -path "./${GIT_SHADOW_CONFIG_FILE}" -print | sed 's|^\./||'
    ) | while IFS= read -r relative_path; do
    
        SOURCE_PATH="${TEMP_DIR}/${relative_path}"
        DEST_PATH="${REPO_ROOT}/${relative_path}"

        # ⭐️ SAFETY CHECK ⭐️
        # Check if the path is ignored on the *current* branch
        if ! git -C "${REPO_ROOT}" check-ignore -q "${relative_path}"; then
            echo "Warning: Skipping pull for '${relative_path}': Not ignored on current branch." >&2
            continue
        fi

        # If we are here, it's safe to restore
        echo "  <- Restoring: ${relative_path}"
        mkdir -p "$(dirname "${DEST_PATH}")"
        cp "${SOURCE_PATH}" "${DEST_PATH}"

    done
    
    # Also pull the config file itself, if it's ignored
    if git -C "${REPO_ROOT}" check-ignore -q "${GIT_SHADOW_CONFIG_FILE}"; then
        echo "  <- Restoring: ${GIT_SHADOW_CONFIG_FILE}"
        cp "${TEMP_DIR}/${GIT_SHADOW_CONFIG_FILE}" "${REPO_ROOT}/${GIT_SHADOW_CONFIG_FILE}"
    fi

    rm -rf "$TEMP_DIR"
    echo "Shadow pull complete. Files are restored in your working directory."
}