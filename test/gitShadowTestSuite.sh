#!/usr/bin/env bash
# @file git-shadow-tests.sh
# @brief Test suite for the git-shadow utility (Pattern-based logic)

# Main test suite function 🎯
gitShadowTestSuite() {
  export LC_NUMERIC=C  # 🔢

  # --- Test Environment Setup ---
  echo "Setting up test environment..."
  local GIT_SHADOW_TEST_ROOT=$(mktemp -d)
  local GIT_SHADOW_REMOTE_REPO="${GIT_SHADOW_TEST_ROOT}/remote.git"
  local GIT_SHADOW_LOCAL_REPO="${GIT_SHADOW_TEST_ROOT}/local"

  git init --bare "$GIT_SHADOW_REMOTE_REPO" >/dev/null
  git clone "$GIT_SHADOW_REMOTE_REPO" "$GIT_SHADOW_LOCAL_REPO" >/dev/null

  (
    cd "$GIT_SHADOW_LOCAL_REPO"
    git config user.email "test@example.com"
    git config user.name "Test Bot"
    touch README.md
    git add README.md
    git commit -m "Initial commit" >/dev/null
    git push origin master >/dev/null
  )
  echo "Test environment ready at $GIT_SHADOW_LOCAL_REPO"
  echo "---"
  
  # --- Individual Test Functions 🧩 ---

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

  # --- Test function registry 📋 ---
  local test_functions=(
    "git_shadow_test_init"
    "git_shadow_test_add_and_push_patterns"
    "git_shadow_test_pull_patterns"
    "git_shadow_test_move_detection"
    "git_shadow_test_safety_check_pull"
    "testGitShadowExponentialNestingBug"
    "testGitShadowGithubIntegration"
  )

  local ignored_tests=()  # 🚫

  bashTestRunner test_functions ignored_tests
  local result=$?

  # --- Test Environment Teardown ---
  echo "---"
  echo "Cleaning up test environment..."
  rm -rf "$GIT_SHADOW_TEST_ROOT"
  
  return $result  # 🎉 Done!
}
