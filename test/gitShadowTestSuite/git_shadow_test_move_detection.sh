#!/usr/bin/env bash
git_shadow_test_move_detection() {
    echo "🚚 Testing 'move' detection via push..."
    cd "$GIT_SHADOW_LOCAL_REPO"
    
    # 1. Move a directory
    mkdir -p "new/location"
    mv "src/ai-chat-data" "new/location/"
    
    # 2. Run push. This should detect the 'move' (as a delete + add)
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed during move test"
      return 1
    fi

    # 3. Verify on remote
    local TEMP_CLONE=$(mktemp -d)
    git clone --quiet --depth 1 --branch shadow "$GIT_SHADOW_REMOTE_REPO" "$TEMP_CLONE"
    
    # Check that the NEW path exists
    if ! grep -q "data1" "${TEMP_CLONE}/new/location/ai-chat-data/file.txt"; then
      echo "❌ ERROR: 'push' did not upload moved file to new location"
      rm -rf "$TEMP_CLONE"
      return 1
    fi
    
    # Check that the OLD path is GONE
    if [ -e "${TEMP_CLONE}/src/ai-chat-data" ]; then
      echo "❌ ERROR: 'push' did not delete the old file path"
      rm -rf "$TEMP_CLONE"
      return 1
    fi
    
    rm -rf "$TEMP_CLONE"
    echo "✅ SUCCESS: push correctly handled the file 'move'"
    return 0
  }