git-shadow-push() {
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
    local CONFIG_PATH
    local pattern
    local file_path
    local relative_path

    git_shadow_check_in_repo || return 1

    REPO_ROOT=$(git_shadow_get_repo_root)
    REPO_URL=$(git_shadow_get_repo_url)
    TEMP_DIR=$(mktemp -d)

    echo "Cloning shadow branch to temporary directory..."
    git clone --quiet --depth 1 --branch "${GIT_SHADOW_BRANCH}" "${REPO_URL}" "$TEMP_DIR"

    CONFIG_PATH="${TEMP_DIR}/${GIT_SHADOW_CONFIG_FILE}"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo "Error: '${GIT_SHADOW_CONFIG_FILE}' not found in shadow branch." >&2
        rm -rf "$TEMP_DIR"
        return 1
    fi

    echo "Cleaning old files from temporary shadow branch..."
    (
        cd "$TEMP_DIR"
        # Find all files/dirs *except* the .git dir and the config file, then delete
        find . -mindepth 1 -not -path "./.git/*" -not -path "./.git" -not -path "./${GIT_SHADOW_CONFIG_FILE}" -exec rm -rf {} +
    )

    echo "Syncing files from working directory to shadow branch..."
    
    # Read patterns from the *temp* config file
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        if [ -z "$pattern" ]; then continue; fi
        if [[ "$pattern" == \#* ]]; then continue; fi

        echo "Searching for pattern: '${pattern}'"
        
        # Find all files/dirs matching the pattern *in the main repo*
        # We must 'cd' to the repo root to get clean relative paths
        (
            cd "$REPO_ROOT"
            # Using 'find' with -name. This handles patterns like '*.log' or 'ai-chat-data'
            # Note: This is a simple -name match. For globstar `**` it would be more complex.
            # We strip the leading ./ from find's output
            find . -name "$pattern" -print | sed 's|^\./||'
        ) | while IFS= read -r file_path; do

            relative_path="$file_path"
            
            # ⭐️ SAFETY CHECK ⭐️
            if ! git -C "${REPO_ROOT}" check-ignore -q "${relative_path}"; then
                echo "Warning: Skipping push for '${relative_path}': Not ignored on current branch." >&2
                continue
            fi

            # Check if file exists (find should ensure this, but good practice)
            if [ ! -e "${REPO_ROOT}/${relative_path}" ]; then
                continue
            fi
            
            echo "  -> Staging: ${relative_path}"
            
            # Copy from main repo TO temp clone, preserving path
            mkdir -p "${TEMP_DIR}/$(dirname "${relative_path}")"
            cp -r "${REPO_ROOT}/${relative_path}" "${TEMP_DIR}/${relative_path}"

        done
    done < <(grep -vE '^\s*#|^\s*$' "${CONFIG_PATH}")

    # Commit and push the changes
    (
        cd "$TEMP_DIR"
        git add .
        
        if git diff --staged --quiet; then
            echo "No changes to push."
        else
            echo "Committing and pushing changes..."
            git commit -m "shadow: sync files" >/dev/null
            git push "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}" >/dev/null
            echo "Push complete."
        fi
    )

    rm -rf "$TEMP_DIR"
    echo "Shadow push finished."
}
