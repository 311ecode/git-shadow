#!/usr/bin/env bash
git_shadow_test_add_and_push_patterns() {
    echo "🧪 Testing git_shadow_test_add_and_push_patterns..."
    cd "$GIT_SHADOW_LOCAL_REPO"
    
    local PATTERN_DIR="ai-chat-data"
    local PATTERN_FILE="secrets.env"
    local CONTENT_1="data1"
    local CONTENT_2="data2"
    local CONTENT_3="secret"

    # Create multiple files matching the patterns
    mkdir -p "src/${PATTERN_DIR}"
    echo "$CONTENT_1" > "src/${PATTERN_DIR}/file.txt"
    
    mkdir -p "lib/${PATTERN_DIR}"
    echo "$CONTENT_2" > "lib/${PATTERN_DIR}/other.txt"
    
    echo "$CONTENT_3" > "src/${PATTERN_FILE}"
    
    # 1. Add patterns to .gitignore
    echo "${PATTERN_DIR}/" >> .gitignore
    echo "${PATTERN_FILE}" >> .gitignore
    echo ".git-shadow-config" >> .gitignore # Also ignore the config
    git add .gitignore
    git commit -m "Ignore patterns" >/dev/null

    # 2. Run git-shadow-add for both patterns
    if ! git-shadow-add "$PATTERN_DIR" >/dev/null; then return 1; fi
    if ! git-shadow-add "$PATTERN_FILE" >/dev/null; then return 1; fi
    
    # 3. Run git-shadow-push
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed"
      return 1
    fi

    # 4. Verify on remote
    local TEMP_CLONE=$(mktemp -d)
    git clone --quiet --depth 1 --branch shadow "$GIT_SHADOW_REMOTE_REPO" "$TEMP_CLONE"
    
    # Check that all 3 files were pushed
    if ! grep -q "$CONTENT_1" "${TEMP_CLONE}/src/${PATTERN_DIR}/file.txt"; then
      echo "❌ ERROR: 'push' did not upload src/ai-chat-data"
      rm -rf "$TEMP_CLONE"
      return 1
    fi
    if ! grep -q "$CONTENT_2" "${TEMP_CLONE}/lib/${PATTERN_DIR}/other.txt"; then
      echo "❌ ERROR: 'push' did not upload lib/ai-chat-data"
      rm -rf "$TEMP_CLONE"
      return 1
    fi
    if ! grep -q "$CONTENT_3" "${TEMP_CLONE}/src/${PATTERN_FILE}"; then
      echo "❌ ERROR: 'push' did not upload src/secrets.env"
      rm -rf "$TEMP_CLONE"
      return 1
    fi
    
    rm -rf "$TEMP_CLONE"
    echo "✅ SUCCESS: add and push stored all files matching patterns"
    return 0
  }