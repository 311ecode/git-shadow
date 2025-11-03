#!/bin/bash
git_shadow_sync_persistent_clone() {
    (
        cd "${GIT_SHADOW_PERSISTENT_DIR}"
        git add .
        if ! git diff --staged --quiet; then
            git commit -m "shadow: sync files" >/dev/null
            git push --quiet "${GIT_SHADOW_REMOTE}" "${GIT_SHADOW_BRANCH}" >/dev/null
        fi
    )
}
