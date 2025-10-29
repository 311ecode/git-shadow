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
    local CONFIG_PATH
    local file_path
    local SOURCE_PATH
    local DEST_PATH

    git_shadow_check_in_repo || return 1

    REPO_ROOT=$(git_shadow_get_repo_root)
    REPO_URL=$(git_shadow_get_repo_url)
    TEMP_DIR=$(mktemp -d)

    echo "Cloning shadow branch to temporary directory..."
    git clone --quiet --depth 1 --branch "${GIT_SHADOW_BRANCH}" "${REPO_URL}" "$TEMP_DIR"

    CONFIG_PATH="${TEMP_DIR}/${GIT_SHADOW_CONFIG_FILE}"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo "Error: '${GIT_SHADOW_CONFIG_FILE}' not found in shadow branch." >&2
        echo "Run 'git-shadow-init' or 'git-shadow-add' first." >&2
        rm -rf "$TEMP_DIR"
        return 1
    fi

    echo "Syncing files from shadow branch to working directory..."

    while IFS= read -r file_path || [ -n "$file_path" ]; do
        if [ -z "$file_path" ]; then continue; fi
        if [[ "$file_path" == \#* ]]; then continue; fi

        SOURCE_PATH="${TEMP_DIR}/${file_path}"
        DEST_PATH="${REPO_ROOT}/${file_path}"

        if [ ! -e "${SOURCE_PATH}" ]; then
            echo "Warning: '${file_path}' listed in config but not found in shadow branch. Skipping." >&2
            continue
        fi

        mkdir -p "$(dirname "${DEST_PATH}")"
        cp -r "${SOURCE_PATH}" "${DEST_PATH}"
        echo "  <- Restoring: ${file_path}"

    done < <(grep -vE '^\s*#|^\s*$' "${CONFIG_PATH}")

    rm -rf "$TEMP_DIR"
    echo "Shadow pull complete. Files are restored in your working directory."
}
