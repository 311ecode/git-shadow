git-shadow-pull() {
    # --- Configuration ---
    local GIT_SHADOW_BRANCH="shadow"
    local GIT_SHADOW_CONFIG_FILE=".git-shadow-config"
    local GIT_SHADOW_REMOTE="origin"
    local GIT_SHADOW_TEMP_DIR="${GIT_SHADOW_TEMP_DIR:-/tmp/git-shadow-$$}"
    local GIT_SHADOW_PERSISTENT_DIR="${GIT_SHADOW_TEMP_DIR}/persistent-shadow"

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

    git_shadow_ensure_persistent_clone() {
        local REPO_URL="$1"
        
        if [ ! -d "${GIT_SHADOW_PERSISTENT_DIR}/.git" ]; then
            echo "Creating persistent shadow clone..."
            mkdir -p "${GIT_SHADOW_PERSISTENT_DIR}"
            git clone --quiet --branch "${GIT_SHADOW_BRANCH}" "${REPO_URL}" "${GIT_SHADOW_PERSISTENT_DIR}" >/dev/null 2>&1
            
            if [ $? -ne 0 ]; then
                echo "Error: Could not clone shadow branch. Please run 'git-shadow-init' first." >&2
                rm -rf "${GIT_SHADOW_PERSISTENT_DIR}"
                return 1
            fi
        else
            # Update existing persistent clone
            (
                cd "${GIT_SHADOW_PERSISTENT_DIR}"
                git pull --quiet "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}" >/dev/null 2>&1
            )
        fi
        
        return 0
    }

    # --- Main Logic ---
    local REPO_ROOT
    local REPO_URL
    local relative_path
    local SOURCE_PATH
    local DEST_PATH

    git_shadow_check_in_repo || return 1

    REPO_ROOT=$(git_shadow_get_repo_root)
    REPO_URL=$(git_shadow_get_repo_url)

    echo "Setting up persistent shadow clone..."
    git_shadow_ensure_persistent_clone "$REPO_URL" || return 1

    echo "Syncing all files from shadow branch to working directory..."

    # Find ALL files in the persistent clone, except .git and the config file
    (
        cd "$GIT_SHADOW_PERSISTENT_DIR"
        find . -mindepth 1 -type f -not -path "./.git/*" -not -path "./${GIT_SHADOW_CONFIG_FILE}" -print | sed 's|^\./||'
    ) | while IFS= read -r relative_path; do
    
        SOURCE_PATH="${GIT_SHADOW_PERSISTENT_DIR}/${relative_path}"
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
        cp "${GIT_SHADOW_PERSISTENT_DIR}/${GIT_SHADOW_CONFIG_FILE}" "${REPO_ROOT}/${GIT_SHADOW_CONFIG_FILE}"
    fi

    echo "Shadow pull complete. Files are restored in your working directory."
    echo "Persistent clone maintained at: $GIT_SHADOW_PERSISTENT_DIR"
}
