git-shadow-init() {
    # --- Configuration ---
    local GIT_SHADOW_BRANCH="shadow"
    local GIT_SHADOW_CONFIG_FILE=".git-shadow-config"
    local GIT_SHADOW_REMOTE="origin"
    
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
    local SCRIPT_DIR

    git_shadow_check_in_repo || return 1
    REPO_URL=$(git_shadow_get_repo_url) || return 1

    echo "Checking for shadow branch '${GIT_SHADOW_BRANCH}' on remote '${GIT_SHADOW_REMOTE}'..."

    if git ls-remote --exit-code --heads "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}" >/dev/null 2>&1; then
        echo "Shadow branch '${GIT_SHADOW_BRANCH}' already exists on remote."
    else
        echo "Shadow branch not found. Creating it..."
        
        TEMP_DIR=$(mktemp -d)
        
        (
            cd "$TEMP_DIR"
            git init -b "${GIT_SHADOW_BRANCH}" >/dev/null
            echo "# Git Shadow Config - Lists files/dirs to be tracked in this branch" > "${GIT_SHADOW_CONFIG_FILE}"
            git add "${GIT_SHADOW_CONFIG_FILE}"
            git commit -m "shadow: initialize shadow config" >/dev/null
            git remote add "${GIT_SHADOW_REMOTE}" "${REPO_URL}"
            git push -u "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}" >/dev/null
        )
        
        rm -rf "$TEMP_DIR"
        echo "Successfully created and pushed new branch '${GIT_SHADOW_BRANCH}'."
    fi

    echo ""
    echo "Initialization complete."
    echo "Running an initial 'pull' to restore any existing shadow files..."

    if command -v git-shadow-pull >/dev/null 2>&1; then
        git-shadow-pull
    else
        echo "Warning: 'git-shadow-pull' function not found. Skipping initial pull." >&2
        echo "Please run 'git-shadow-pull' manually." >&2
    fi

    echo ""
    echo "Reminder: Use 'git-shadow-add <path>' to add ignored files to the shadow config."
}
