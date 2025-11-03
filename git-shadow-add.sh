git-shadow-add() {
    # --- Configuration ---
    local GIT_SHADOW_BRANCH="shadow"
    local GIT_SHADOW_CONFIG_FILE=".git-shadow-config"
    local GIT_SHADOW_REMOTE="origin"
    local GIT_SHADOW_TEMP_DIR="${GIT_SHADOW_TEMP_DIR:-/tmp/git-shadow}"
    local REPO_ROOT
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    local REPO_HASH
    REPO_HASH=$(echo -n "$REPO_ROOT" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "default")
    local GIT_SHADOW_PERSISTENT_DIR="${GIT_SHADOW_TEMP_DIR}/${REPO_HASH}/persistent-shadow"

    # --- Helper Functions ---
    git_shadow_check_in_repo() {
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: This command must be run inside a Git repository." >&2; return 1; }
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
                echo "Warning: Could not clone shadow branch. It may not exist yet." >&2
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
    local PATTERN="$1"
    local REPO_URL
    local CONFIG_PATH

    git_shadow_check_in_repo || return 1

    if [ -z "$PATTERN" ]; then
        echo "Usage: git-shadow-add <pattern-to-track>" >&2
        echo "Example: git-shadow-add 'ai-chat-data'" >&2
        echo "Example: git-shadow-add '*.log'" >&2
        return 1
    fi

    echo "Adding pattern '${PATTERN}' to shadow config..."

    REPO_URL=$(git_shadow_get_repo_url)

    echo "Setting up persistent shadow clone..."
    git_shadow_ensure_persistent_clone "$REPO_URL" || return 1

    CONFIG_PATH="${GIT_SHADOW_PERSISTENT_DIR}/${GIT_SHADOW_CONFIG_FILE}"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo "Error: '${GIT_SHADOW_CONFIG_FILE}' not found in shadow branch." >&2
        echo "Please run 'git-shadow-init' first." >&2
        return 1
    fi

    if grep -qFx "$PATTERN" "$CONFIG_PATH"; then
        echo "'${PATTERN}' is already in the shadow config. No changes made."
        return 0
    fi

    echo "${PATTERN}" >> "${CONFIG_PATH}"

    (
        cd "$GIT_SHADOW_PERSISTENT_DIR"
        git add "${GIT_SHADOW_CONFIG_FILE}"
        git commit -m "shadow: add '${PATTERN}' to config"
        git push "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}"
    ) >/dev/null

    echo "Successfully added '${PATTERN}' to shadow config."
    echo "Run 'git-shadow-push' to upload matching files."
    echo "Persistent clone maintained at: $GIT_SHADOW_PERSISTENT_DIR"
}
