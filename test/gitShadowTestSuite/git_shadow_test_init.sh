#!/usr/bin/env bash
git_shadow_test_init() {
    echo "🧪 Testing git_shadow_test_init..."
    cd "$GIT_SHADOW_LOCAL_REPO"
    
    if ! git-shadow-init >/dev/null; then
      echo "❌ ERROR: git-shadow-init function failed"
      return 1
    fi

    if ! git ls-remote --exit-code --heads "origin" "shadow" >/dev/null 2>&1; then
      echo "❌ ERROR: 'shadow' branch was not created on remote"
      return 1
    fi
    echo "✅ SUCCESS: init created remote branch"
    return 0
  }