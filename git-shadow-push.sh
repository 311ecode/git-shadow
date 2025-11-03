git-shadow-push() {
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
    local REPO_URL
    local CONFIG_PATH
    local pattern
    local file_path
    local relative_path

    git_shadow_check_in_repo || return 1

    REPO_ROOT=$(git_shadow_get_repo_root)
    REPO_URL=$(git_shadow_get_repo_url)

    echo "Setting up persistent shadow clone..."
    git_shadow_ensure_persistent_clone "$REPO_URL" || return 1

    CONFIG_PATH="${GIT_SHADOW_PERSISTENT_DIR}/${GIT_SHADOW_CONFIG_FILE}"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo "Error: '${GIT_SHADOW_CONFIG_FILE}' not found in shadow branch." >&2
        return 1
    fi

    echo "Cleaning old files from persistent shadow clone..."
    (
        cd "$GIT_SHADOW_PERSISTENT_DIR"
        find . -mindepth 1 -not -path "./.git/*" -not -path "./.git" -not -path "./${GIT_SHADOW_CONFIG_FILE}" -exec rm -rf {} + 2>/dev/null || true
    )

    echo "Syncing files from working directory to shadow branch..."
    
    # Read patterns from the persistent clone's config file
    while IFS= read -r pattern || [ -n "$pattern" ]; do
        if [ -z "$pattern" ]; then continue; fi
        if [[ "$pattern" == \#* ]]; then continue; fi

        echo "Searching for pattern: '${pattern}'"
        
        # Find all files/dirs matching the pattern *in the main repo*
        (
            cd "$REPO_ROOT"
            find . -name "$pattern" -print | sed 's|^\./||'
        ) | while IFS= read -r file_path; do

            relative_path="$file_path"
            
            # ⭐️ SAFETY CHECK ⭐️
            if ! git -C "${REPO_ROOT}" check-ignore -q "${relative_path}"; then
                echo "Warning: Skipping push for '${relative_path}': Not ignored on current branch." >&2
                continue
            fi

            # Check if file/dir exists
            if [ ! -e "${REPO_ROOT}/${relative_path}" ]; then
                continue
            fi
            
            echo "  -> Staging: ${relative_path}"
            
            # Copy from main repo TO persistent clone, preserving path
            mkdir -p "${GIT_SHADOW_PERSISTENT_DIR}/$(dirname "${relative_path}")"
            cp -r "${REPO_ROOT}/${relative_path}" "${GIT_SHADOW_PERSISTENT_DIR}/${relative_path}"

        done
    done < <(grep -vE '^\s*#|^\s*$' "${CONFIG_PATH}")

    # Commit and push the changes
    (
        cd "$GIT_SHADOW_PERSISTENT_DIR"
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

    echo "Shadow push finished."
    echo "Persistent clone maintained at: $GIT_SHADOW_PERSISTENT_DIR"
}
