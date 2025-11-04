#!/usr/bin/env bash
git_shadow_test_safety_check_pull() {
    echo "⚠️ Testing SAFETY: git_shadow_test_safety_check_pull"
    cd "$GIT_SHADOW_LOCAL_REPO"
    
    # This file IS on the shadow branch from previous tests
    local TEST_FILE="src/secrets.env" 
    local LOCAL_CONTENT="LOCAL_VERSION_DO_NOT_OVERWRITE"

    # 1. Create a new branch where this file is NOT ignored
    git checkout -b feature-branch >/dev/null
    echo "README.md" > .gitignore # Overwrite .gitignore
    echo ".git-shadow-config" >> .gitignore # But still ignore the config
    git add .gitignore
    git commit -m "Stop ignoring secrets" >/dev/null
    
    # 2. Modify the local file
    mkdir -p "src"
    echo "$LOCAL_CONTENT" > "$TEST_FILE"
    
    # 3. Run pull
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed"
      return 1
    fi
    
    # 4. Verify the local file was NOT overwritten
    if ! grep -q "$LOCAL_CONTENT" "$TEST_FILE"; then
      echo "❌ ERROR: 'pull' OVERWROTE a tracked file! Safety check failed!"
      return 1
    fi
    
    echo "✅ SUCCESS: 'pull' correctly skipped a non-ignored file"
    return 0
  }