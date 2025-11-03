#!/bin/bash
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
