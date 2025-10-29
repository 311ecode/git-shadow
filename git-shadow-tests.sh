#!/usr/bin/env bash
# @file git-shadow-tests.sh
# @brief Test suite for the git-shadow utility
# @description Provides integration tests for init, add, push, pull,
# and the critical branch-safety checks.

# Main test suite function 🎯
git_shadow_test_suite() {
  export LC_NUMERIC=C  # 🔢 Ensures consistent numbers!

  # --- Test Environment Setup ---
  echo "Setting up test environment..."
  local GIT_SHADOW_TEST_ROOT=$(mktemp -d)
  local GIT_SHADOW_REMOTE_REPO="${GIT_SHADOW_TEST_ROOT}/remote.git"
  local GIT_SHADOW_LOCAL_REPO="${GIT_SHADOW_TEST_ROOT}/local"

  # Create a bare "remote" repo
  git init --bare "$GIT_SHADOW_REMOTE_REPO" >/dev/null
  
  # Clone it to our "local" workspace
  git clone "$GIT_SHADOW_REMOTE_REPO" "$GIT_SHADOW_LOCAL_REPO" >/dev/null

  # Configure the local repo for commits
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
    
    # ⭐️ PREREQUISITE: A user must ignore the config file *before* init
    echo ".git-shadow-config" >> .gitignore
    git add .gitignore
    git commit -m "Ignore shadow config" >/dev/null

    echo "DEBUG: Running git-shadow-init..."
    if ! git-shadow-init >/dev/null; then
      echo "❌ ERROR: git-shadow-init function failed"
      return 1
    fi

    echo "DEBUG: Checking for remote shadow branch..."
    if ! git ls-remote --exit-code --heads "origin" "shadow" >/dev/null 2>&1; then
      echo "❌ ERROR: 'shadow' branch was not created on remote"
      return 1
    fi
    
    echo "DEBUG: Checking for local config file after pull..."
    if [ ! -f ".git-shadow-config" ]; then
      echo "❌ ERROR: .git-shadow-config was not created by initial pull"
      return 1
    fi
    
    echo "✅ SUCCESS: init created remote branch and pulled config"
    return 0
  }

  git_shadow_test_add_and_push() {
    echo "🧪 Testing git_shadow_test_add_and_push..."
    cd "$GIT_SHADOW_LOCAL_REPO"
    local TEST_FILE="config/secrets.env"
    local TEST_CONTENT="SECRET_KEY=12345"

    mkdir -p "$(dirname "$TEST_FILE")"
    echo "$TEST_CONTENT" > "$TEST_FILE"
    
    echo "DEBUG: Ignoring test file..."
    echo "$TEST_FILE" >> .gitignore
    git add .gitignore
    git commit -m "Ignore secrets" >/dev/null

    echo "DEBUG: Running git-shadow-add..."
    if ! git-shadow-add "$TEST_FILE" >/dev/null; then
      echo "❌ ERROR: git-shadow-add failed"
      return 1
    fi
    
    echo "DEBUG: Running git-shadow-push..."
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed"
      return 1
    fi

    echo "DEBUG: Verifying remote..."
    local TEMP_CLONE=$(mktemp -d)
    git clone --quiet --depth 1 --branch shadow "$GIT_SHADOW_REMOTE_REPO" "$TEMP_CLONE"
    
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
  
  git_shadow_test_pull() {
    echo "🧪 Testing git_shadow_test_pull..."
    cd "$GIT_SHADOW_LOCAL_REPO"
    local TEST_FILE="config/secrets.env" # This file exists from the last test
    
    echo "DEBUG: Removing local file..."
    rm -f "$TEST_FILE"
    if [ -f "$TEST_FILE" ]; then
      echo "❌ ERROR: Could not remove local file for pull test"
      return 1
    fi
    
    echo "DEBUG: Running git-shadow-pull..."
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed"
      return 1
    fi
    
    echo "DEBUG: Verifying file restoration..."
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
  
  git_shadow_test_safety_check_pull() {
    echo "⚠️ Testing SAFETY: git_shadow_test_safety_check_pull"
    cd "$GIT_SHADOW_LOCAL_REPO"
    local TEST_FILE="config/secrets.env" # This file is in shadow config
    local LOCAL_CONTENT="LOCAL_VERSION_DO_NOT_OVERWRITE"

    echo "DEBUG: Creating feature-branch..."
    git checkout -b feature-branch >/dev/null
    # Overwrite .gitignore to "un-ignore" the secret file
    # BUT we must still ignore the .git-shadow-config file itself!
    echo "README.md" > .gitignore
    echo ".git-shadow-config" >> .gitignore
    git add .gitignore
    git commit -m "Stop ignoring secrets" >/dev/null
    
    echo "DEBUG: Modifying local tracked file..."
    echo "$LOCAL_CONTENT" > "$TEST_FILE"
    
    echo "DEBUG: Running git-shadow-pull (expecting skip)..."
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed during safety test"
      return 1
    fi
    
    echo "DEBUG: Verifying local file was NOT overwritten..."
    if ! grep -q "$LOCAL_CONTENT" "$TEST_FILE"; then
      echo "❌ ERROR: 'pull' OVERWROTE a tracked file! Safety check failed!"
      return 1
    fi
    
    echo "✅ SUCCESS: 'pull' correctly skipped a non-ignored file"
    return 0
  }
  
  git_shadow_test_safety_check_push() {
    echo "⚠️ Testing SAFETY: git_shadow_test_safety_check_push"
    cd "$GIT_SHADOW_LOCAL_REPO"
    # We are still on 'feature-branch' where TEST_FILE is tracked
    local TEST_FILE="config/secrets.env" 
    local LOCAL_CONTENT="NEW_LOCAL_VERSION"
    
    echo "DEBUG: Modifying local tracked file..."
    echo "$LOCAL_CONTENT" > "$TEST_FILE"
    
    echo "DEBUG: Running git-shadow-push (expecting skip)..."
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed during safety test"
      return 1
    fi
    
    echo "DEBUG: Verifying remote file was NOT overwritten..."
    local TEMP_CLONE=$(mktemp -d)
    git clone --quiet --depth 1 --branch shadow "$GIT_SHADOW_REMOTE_REPO" "$TEMP_CLONE"
    
    # Check for the *original* content
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
    "git_shadow_test_init"
    "git_shadow_test_add_and_push"
    "git_shadow_test_pull"
    "git_shadow_test_safety_check_pull"
    "git_shadow_test_safety_check_push"
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

# --- Execute if run directly 🚀 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # ⭐️ Enable full debug tracing for the test run ⭐️
  set -x
  
  # Source the functions we are testing
  # Assumes they are in the same directory as this test script
  SCRIPT_DIR=$(dirname "$0")
  source "${SCRIPT_DIR}/git-shadow-init.sh"
  source "${SCRIPT_DIR}/git-shadow-add.sh"
  source "${SCRIPT_DIR}/git-shadow-push.sh"
  source "${SCRIPT_DIR}/git-shadow-pull.sh"
  
  # Run the suite
  git_shadow_test_suite
  
  # Disable debug tracing
  set +x
fi
