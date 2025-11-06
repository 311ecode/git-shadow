git-shadow-init() {
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
        local url
        url=$(git config --get "remote.${GIT_SHADOW_REMOTE}.url")
        if [ -z "$url" ]; then
            echo "Error: Could not find remote URL for '${GIT_SHADOW_REMOTE}'." >&2
            echo "Please ensure your remote is set up." >&2
            return 1
        fi
        echo "$url"
    }

    # --- Main Logic ---
    local REPO_URL
    local TEMP_DIR

    git_shadow_check_in_repo || return 1
    REPO_URL=$(git_shadow_get_repo_url) || return 1

    echo "Checking for shadow branch '${GIT_SHADOW_BRANCH}' on remote '${GIT_SHADOW_REMOTE}'..."

    if git ls-remote --exit-code --heads "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}" >/dev/null 2>&1; then
        echo "Shadow branch '${GIT_SHADOW_BRANCH}' already exists on remote."
    else
        echo "Shadow branch not found. Creating it..."
        
        # Use persistent temp directory
        TEMP_DIR="${GIT_SHADOW_TEMP_DIR}/init-$(date +%s)"
        mkdir -p "$TEMP_DIR"
        
        (
            cd "$TEMP_DIR"
            git init -b "${GIT_SHADOW_BRANCH}" >/dev/null
            echo "# Git Shadow Config - Lists patterns (e.g., 'secrets.env' or 'ai-chat-data') to track" > "${GIT_SHADOW_CONFIG_FILE}"
            git add "${GIT_SHADOW_CONFIG_FILE}"
            git commit -m "shadow: initialize shadow config" >/dev/null
            git remote add "${GIT_SHADOW_REMOTE}" "${REPO_URL}"
            git push -u "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}" >/dev/null
        )
        
        echo "Successfully created and pushed new branch '${GIT_SHADOW_BRANCH}'."
        echo "Temporary directory preserved at: $TEMP_DIR"
    fi

    echo ""
    echo "Initialization complete."
    echo "Reminder: Run 'git-shadow-pull' to get the latest shadow files."
    echo "Reminder: Use 'git-shadow-add <pattern>' to add files to the shadow config."
}
