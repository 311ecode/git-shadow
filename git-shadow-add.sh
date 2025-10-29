git-shadow-add() {
    # --- Configuration ---
    local GIT_SHADOW_BRANCH="shadow"
    local GIT_SHADOW_CONFIG_FILE=".git-shadow-config"
    local GIT_SHADOW_REMOTE="origin"

    # --- Helper Functions ---
    git_shadow_check_in_repo() {
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: This command must be run inside a Git repository." >&2; return 1; }
    }

    git_shadow_get_repo_url() {
        git config --get "remote.${GIT_SHADOW_REMOTE}.url"
    }

    # --- Main Logic ---
    local PATTERN="$1"
    local TEMP_DIR
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

    TEMP_DIR=$(mktemp -d)
    REPO_URL=$(git_shadow_get_repo_url)

    git clone --quiet --depth 1 --branch "${GIT_SHADOW_BRANCH}" "${REPO_URL}" "$TEMP_DIR"

    CONFIG_PATH="${TEMP_DIR}/${GIT_SHADOW_CONFIG_FILE}"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo "Error: '${GIT_SHADOW_CONFIG_FILE}' not found in shadow branch." >&2
        echo "Please run 'git-shadow-init' first." >&2
        rm -rf "$TEMP_DIR"
        return 1
    fi

    if grep -qFx "$PATTERN" "$CONFIG_PATH"; then
        echo "'${PATTERN}' is already in the shadow config. No changes made."
        rm -rf "$TEMP_DIR"
        return 0
    fi

    echo "${PATTERN}" >> "${CONFIG_PATH}"

    (
        cd "$TEMP_DIR"
        git add "${GIT_SHADOW_CONFIG_FILE}"
        git commit -m "shadow: add '${PATTERN}' to config"
        git push "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}"
    ) >/dev/null

    rm -rf "$TEMP_DIR"
    echo "Successfully added '${PATTERN}' to shadow config."
    echo "Run 'git-shadow-push' to upload matching files."
}
