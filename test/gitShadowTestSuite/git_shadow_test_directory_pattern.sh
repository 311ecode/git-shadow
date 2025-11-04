#!/usr/bin/env bash
git_shadow_test_directory_pattern() {
    echo "🧪 Testing directory-style pattern (e.g., 'docs/science')..."
    cd "$GIT_SHADOW_LOCAL_REPO"
    
    local DIR_PATTERN="docs/science"
    local FILE_CONTENT="E=mc^2 is shadow data"

    # 1. Create directory and a file inside it
    mkdir -p "$DIR_PATTERN"
    echo "$FILE_CONTENT" > "${DIR_PATTERN}/einstein.txt"

    # 2. Add pattern to .gitignore
    # NOTE: We also need to ignore the parent 'docs/' if we want 'docs/science' to be found
    # otherwise, 'docs' might be tracked, making 'docs/science' tracked as well.
    # However, for simplicity and testing the pattern logic directly, we just ensure
    # the directory itself is ignored.
    echo "${DIR_PATTERN}/" >> .gitignore
    git add .gitignore
    git commit --amend --no-edit >/dev/null # Amend previous commit to avoid pollution

    # 3. Run git-shadow-add for the directory pattern
    # NOTE: Assuming 'docs/science' is added to the config and found by 'find . -path "*/docs/science"'
    if ! git-shadow-add "$DIR_PATTERN" >/dev/null; then return 1; fi
    
    # 4. Run git-shadow-push
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed for directory pattern"
      return 1
    fi

    # 5. Verify push on remote: check the persistent clone directly
    local REPO_ROOT
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    local REPO_HASH
    REPO_HASH=$(echo -n "$REPO_ROOT" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "default")
    local GIT_SHADOW_PERSISTENT_DIR="/tmp/git-shadow/${REPO_HASH}/persistent-shadow"
    
    if ! grep -q "$FILE_CONTENT" "${GIT_SHADOW_PERSISTENT_DIR}/${DIR_PATTERN}/einstein.txt"; then
      echo "❌ ERROR: 'push' did not upload the file inside ${DIR_PATTERN}"
      return 1
    fi
    
    # 6. Remove local file and run pull
    rm -rf "$DIR_PATTERN"
    
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed for directory pattern"
      return 1
    fi
    
    # 7. Verify pull locally
    if ! grep -q "$FILE_CONTENT" "${DIR_PATTERN}/einstein.txt"; then
      echo "❌ ERROR: 'pull' did not restore the file inside ${DIR_PATTERN}"
      return 1
    fi
    
    echo "✅ SUCCESS: Directory-style pattern ('${DIR_PATTERN}') was added, pushed, and pulled successfully"
    return 0
}
