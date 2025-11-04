#!/usr/bin/env bash
git_shadow_test_pull_patterns() {
    echo "🧪 Testing git_shadow_test_pull_patterns..."
    cd "$GIT_SHADOW_LOCAL_REPO"
    
    # 1. Remove the local files (they exist from the last test)
    rm -rf "src/"
    rm -rf "lib/"
    
    # 2. Run pull
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed"
      return 1
    fi
    
    # 3. Verify all files were restored
    if ! grep -q "data1" "src/ai-chat-data/file.txt"; then
      echo "❌ ERROR: 'pull' did not restore src/ai-chat-data"
      return 1
    fi
    if ! grep -q "data2" "lib/ai-chat-data/other.txt"; then
      echo "❌ ERROR: 'pull' did not restore lib/ai-chat-data"
      return 1
    fi
    if ! grep -q "secret" "src/secrets.env"; then
      echo "❌ ERROR: 'pull' did not restore src/secrets.env"
      return 1
    fi
    
    echo "✅ SUCCESS: pull restored all shadow files from all locations"
    return 0
  }