#!/bin/bash
git_shadow_clean_persistent_clone() {
    if [ -d "${GIT_SHADOW_PERSISTENT_DIR}" ]; then
        (
            cd "${GIT_SHADOW_PERSISTENT_DIR}"
            # Remove all files except .git and config
            find . -mindepth 1 -not -path "./.git/*" -not -path "./.git" -not -path "./${GIT_SHADOW_CONFIG_FILE}" -exec rm -rf {} + 2>/dev/null || true
        )
    fi
}
