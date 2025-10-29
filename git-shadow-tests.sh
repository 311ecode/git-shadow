#!/usr/bin/env bash
# @file git-shadow-tests.sh
# @brief Test suite for the git-shadow utility
# @description Provides integration tests for init, add, push, pull,
# and the critical branch-safety checks.

# Main test suite function 🎯
testGitShadowSuite() {
  export LC_NUMERIC=C  # 🔢 Ensures consistent numbers!

  # --- Test Environment Setup ---
  echo "Setting up test environment..."
  local TEST_ROOT=$(mktemp -d)
  local REMOTE_REPO="${TEST_ROOT}/remote.git"
  local LOCAL_REPO="${TEST_ROOT}/local"

  # Create a bare "remote" repo
  git init --bare "$REMOTE_REPO" >/dev/null
  
  # Clone it to our "local" workspace
  git clone "$REMOTE_REPO" "$LOCAL_REPO" >/dev/null

  # Configure the local repo for commits
  (
    cd "$LOCAL_REPO"
    git config user.email "test@example.com"
    git config user.name "Test Bot"
    touch README.md
    git add README.md
    git commit -m "Initial commit" >/dev/null
    git push origin master >/dev/null
  )
  echo "Test environment ready at $LOCAL_REPO"
  echo "---"
  
  # --- Individual Test Functions 🧩 ---

  testInit() {
    echo "🧪 Testing git-shadow-init..."
    cd "$LOCAL_REPO"

    if ! git-shadow-init >/dev/null; then
      echo "❌ ERROR: git-shadow-init function failed"
      return 1
    fi

    if ! git ls-remote --exit-code --heads "origin" "shadow" >/dev/null 2>&1; then
      echo "❌ ERROR: 'shadow' branch was not created on remote"
      return 1
    fi
    
    # Init also does a pull, so the config file should exist
    if [ ! -f ".git-shadow-config" ]; then
      echo "❌ ERROR: .git-shadow-config was not created by initial pull"
      return 1
    fi
    
    echo "✅ SUCCESS: init created remote branch and pulled config"
    return 0
  }

  testAddAndPush() {
    echo "🧪 Testing git-shadow-add and git-shadow-push..."
    cd "$LOCAL_REPO"
    local TEST_FILE="config/secrets.env"
    local TEST_CONTENT="SECRET_KEY=12345"

    mkdir -p "$(dirname "$TEST_FILE")"
    echo "$TEST_CONTENT" > "$TEST_FILE"
    
    # 1. Add to .gitignore (a prerequisite for 'add')
    echo "$TEST_FILE" >> .gitignore
    git add .gitignore
    git commit -m "Ignore secrets" >/dev/null

    # 2. Run git-shadow-add
    if ! git-shadow-add "$TEST_FILE" >/dev/null; then
      echo "❌ ERROR: git-shadow-add failed"
      return 1
    fi
    
    # 3. Run git-shadow-push
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed"
      return 1
    fi

    # 4. Verify on remote
    local TEMP_CLONE=$(mktemp -d)
    git clone --quiet --depth 1 --branch shadow "$REMOTE_REPO" "$TEMP_CLONE"
    
    if ! grep -q "$TEST_FILE" "${TEMP_CLONE}/.git-shadow-config"; then
      echo "❌ ERROR: 'add' did not update remote config file"
      rm -rf "$TEMP_CLONE"
      return 1
    fi

    if ! grep -q "$TEST_CONTENT" "${TEMP_CLONE}/${TEST_FILE}"; then
      echo "❌ ERROR: 'push' did not upload file content to remote"
      rm -rf "$TEMP_CLONE"
      return 1
    fi
    
    rm -rf "$TEMP_CLONE"
    echo "✅ SUCCESS: add and push stored config and file on remote"
    return 0
  }
  
  testPull() {
    echo "🧪 Testing git-shadow-pull..."
    cd "$LOCAL_REPO"
    local TEST_FILE="config/secrets.env" # This file exists from the last test
    
    # 1. Remove the local file
    rm -f "$TEST_FILE"
    if [ -f "$TEST_FILE" ]; then
      echo "❌ ERROR: Could not remove local file for pull test"
      return 1
    fi
    
    # 2. Run pull
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed"
      return 1
    fi
    
    # 3. Verify file was restored
    if [ ! -f "$TEST_FILE" ]; then
      echo "❌ ERROR: 'pull' did not restore $TEST_FILE"
      return 1
    fi
    
    if ! grep -q "SECRET_KEY=12345" "$TEST_FILE"; then
      echo "❌ ERROR: 'pull' restored file with incorrect content"
      return 1
    fi
    
    echo "✅ SUCCESS: pull restored shadow file correctly"
    return 0
  }
  
  testSafetyCheckPull() {
    echo "⚠️ Testing SAFETY: pull must not overwrite a tracked file"
    cd "$LOCAL_REPO"
    local TEST_FILE="config/secrets.env" # This file is in shadow config
    local LOCAL_CONTENT="LOCAL_VERSION_DO_NOT_OVERWRITE"

    # 1. Create a new branch where this file is NOT ignored
    git checkout -b feature-branch >/dev/null
    echo "README.md" > .gitignore # Overwrite .gitignore to "un-ignore" the file
    git add .gitignore
    git commit -m "Stop ignoring secrets" >/dev/null
    
    # 2. Modify the local file
    echo "$LOCAL_CONTENT" > "$TEST_FILE"
    
    # 3. Run pull
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed during safety test"
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
  
  testSafetyCheckPush() {
    echo "⚠️ Testing SAFETY: push must not upload a tracked file"
    cd "$LOCAL_REPO"
    # We are still on 'feature-branch' where TEST_FILE is tracked
    local TEST_FILE="config/secrets.env" 
    local LOCAL_CONTENT="NEW_LOCAL_VERSION"
    
    # 1. Modify the local file
    echo "$LOCAL_CONTENT" > "$TEST_FILE"
    
    # 2. Run push
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed during safety test"
      return 1
    fi
    
    # 3. Verify the remote file was NOT overwritten
    local TEMP_CLONE=$(mktemp -d)
    git clone --quiet --depth 1 --branch shadow "$REMOTE_REPO" "$TEMP_CLONE"
    
    if ! grep -q "SECRET_KEY=12345" "${TEMP_CLONE}/${TEST_FILE}"; then
      echo "❌ ERROR: 'push' UPLOADED a tracked file! Safety check failed!"
      rm -rf "$TEMP_CLONE"
      return 1
    fi
    
    rm -rf "$TEMP_CLONE"
    echo "✅ SUCCESS: 'push' correctly skipped a non-ignored file"
    return 0
  }

  # --- Test function registry 📋 ---
  local test_functions=(
    "testInit"
    "testAddAndPush"
    "testPull"
    "testSafetyCheckPull"
    "testSafetyCheckPush"
  )

  local ignored_tests=()  # 🚫

  bashTestRunner test_functions ignored_tests
  local result=$?

  # --- Test Environment Teardown ---
  echo "---"
  echo "Cleaning up test environment..."
  rm -rf "$TEST_ROOT"
  
  return $result  # 🎉 Done!
}

# --- Execute if run directly 🚀 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Source the functions we are testing
  # Assumes they are in the same directory as this test script
  SCRIPT_DIR=$(dirname "$0")
  source "${SCRIPT_DIR}/git-shadow-init.sh"
  source "${SCRIPT_DIR}/git-shadow-add.sh"
  source "${SCRIPT_DIR}/git-shadow-push.sh"
  source "${SCRIPT_DIR}/git-shadow-pull.sh"
  
  # Run the suite
  testGitShadowSuite
fi
