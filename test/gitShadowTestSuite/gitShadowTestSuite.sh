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

  # --- Test function registry 📋 ---
  local test_functions=(
    "git_shadow_test_init"
    "git_shadow_test_add_and_push_patterns"
    "git_shadow_test_directory_pattern"
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
