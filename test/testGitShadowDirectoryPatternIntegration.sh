#!/usr/bin/env bash
# @file testGitShadowDirectoryPatternIntegration.sh
# @brief Integration test for git-shadow focusing on directory-style patterns (e.g., 'docs/science')

testGitShadowDirectoryPatternIntegration() {
  export LC_NUMERIC=C
  
  # Check for required environment variables
  if [[ -z "$GITHUB_TEST_TOKEN" ]]; then
    echo "ERROR: GITHUB_TEST_TOKEN environment variable is required" >&2
    return 1
  fi
  
  if [[ -z "$GITHUB_TEST_ORG" ]]; then
    echo "ERROR: GITHUB_TEST_ORG environment variable is required" >&2
    return 1
  fi
  
  local GITHUB_TOKEN="$GITHUB_TEST_TOKEN"
  local GITHUB_OWNER="$GITHUB_TEST_ORG"
  
  export TEST_ROOT
  TEST_ROOT=$(mktemp -d)
  
  echo "📁 Test environment: $TEST_ROOT"
  echo "🐙 GitHub owner: $GITHUB_OWNER"
  
  local REPO_NAME="git-shadow-dir-test-$(date +%s)-$$"
  local REPO_URL=""
  local REPO_CREATED=false
  
  cleanup_test_env() {
    echo ""
    echo "🧹 Cleaning up..."
    
    if [[ -d "$TEST_ROOT" ]]; then
      rm -rf "$TEST_ROOT"
      echo "✅ Removed local test directory"
    fi
    
    if [[ "$REPO_CREATED" == "true" ]]; then
      echo "🗑️  Deleting GitHub repository: $GITHUB_OWNER/$REPO_NAME"
      if github_pusher_delete_repo "$GITHUB_OWNER" "$REPO_NAME" "$GITHUB_TOKEN"; then
        echo "✅ GitHub repository deleted"
      else
        echo "⚠️  Failed to delete repository (may need manual cleanup)"
      fi
    fi
  }
  
  trap cleanup_test_env EXIT
  
  testDirectoryPattern() {
    echo ""
    echo "📁 Integration Test: Directory Pattern (docs/science)"
    echo "======================================================"
    
    local DIR_PATTERN="docs/science"
    local FILE_NAME="report.pdf"
    local FILE_CONTENT="Shadow Report Content"
    
    # ============================================================
    # Step 1: Create GitHub repository
    # ============================================================
    echo ""
    echo "STEP 1: Creating GitHub repository"
    echo "-----------------------------------"
    
    REPO_URL=$(github_pusher_create_repo \
      "$GITHUB_OWNER" \
      "$REPO_NAME" \
      "git-shadow directory pattern test" \
      "true" \
      "$GITHUB_TOKEN" \
      "false" \
      "false")
    
    if [[ $? -ne 0 ]] || [[ -z "$REPO_URL" ]]; then
      echo "❌ ERROR: Failed to create GitHub repository"
      return 1
    fi
    
    REPO_CREATED=true
    echo "✅ Created repository: $REPO_URL"
    
    local GIT_REMOTE_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_OWNER}/${REPO_NAME}.git"
    
    # ============================================================
    # Step 2: Set up local repository
    # ============================================================
    echo ""
    echo "STEP 2: Setting up local repository"
    echo "------------------------------------"
    
    local LOCAL_DIR="${TEST_ROOT}/local"
    mkdir -p "$LOCAL_DIR"
    cd "$LOCAL_DIR" || return 1
    
    git init -q
    git config user.email "test@example.com"
    git config user.name "Git Shadow Test"
    git remote add origin "$GIT_REMOTE_URL"
    
    # Create the directory and file
    mkdir -p "$DIR_PATTERN"
    echo "$FILE_CONTENT" > "${DIR_PATTERN}/${FILE_NAME}"
    
    # Create .gitignore - CRITICAL: Ignore the specific directory pattern
    cat > .gitignore << EOF
${DIR_PATTERN}/
.git-shadow-config
EOF
    
    echo "README content" > README.md
    git add README.md .gitignore
    git commit -q -m "Initial commit"
    git push -q origin master
    
    echo "✅ Repository initialized. '${DIR_PATTERN}' is ignored."
    
    # ============================================================
    # Step 3: Initialize git-shadow and add pattern
    # ============================================================
    echo ""
    echo "STEP 3: Initialize and Add Pattern"
    echo "-----------------------------------"
    
    git-shadow-init 2>&1 | grep -v "^Checking\|^Shadow\|^Initialization\|^Reminder"
    git-shadow-add "$DIR_PATTERN"
    echo "✅ git-shadow initialized and pattern added"
    
    # ============================================================
    # Step 4: PUSH
    # ============================================================
    echo ""
    echo "STEP 4: Push to shadow"
    echo "----------------------"
    
    if ! git-shadow-push >/dev/null; then
      echo "❌ ERROR: git-shadow-push failed"
      return 1
    fi
    echo "✅ Files pushed to shadow branch"
    
    # ============================================================
    # Step 5: Verify what's in shadow branch
    # ============================================================
    echo ""
    echo "STEP 5: Verifying shadow branch contents"
    echo "-----------------------------------------"
    
    local SHADOW_CHECK_DIR="${TEST_ROOT}/shadow-check"
    git clone -q --depth 1 --branch shadow "$GIT_REMOTE_URL" "$SHADOW_CHECK_DIR" 2>/dev/null
    
    if ! grep -q "$FILE_CONTENT" "${SHADOW_CHECK_DIR}/${DIR_PATTERN}/${FILE_NAME}"; then
      echo "❌ ERROR: File not found in shadow clone!"
      rm -rf "$SHADOW_CHECK_DIR"
      return 1
    fi
    
    echo "✅ File successfully verified on remote shadow branch."
    rm -rf "$SHADOW_CHECK_DIR"
    
    # ============================================================
    # Step 6: Delete local and PULL
    # ============================================================
    echo ""
    echo "STEP 6: Delete local and Pull from shadow"
    echo "-----------------------------------------"
    
    rm -rf "$DIR_PATTERN"
    echo "🗑️  Deleted local directory."
    
    if ! git-shadow-pull >/dev/null; then
      echo "❌ ERROR: git-shadow-pull failed"
      return 1
    fi
    echo "✅ Pull complete."
    
    # ============================================================
    # Step 7: Verify PULL locally
    # ============================================================
    echo ""
    echo "STEP 7: Verification - Check local restore"
    echo "------------------------------------------"
    
    if ! grep -q "$FILE_CONTENT" "${DIR_PATTERN}/${FILE_NAME}"; then
      echo "❌ ERROR: File not restored locally after pull!"
      return 1
    fi
    
    echo "✅ File restored successfully: ${DIR_PATTERN}/${FILE_NAME}"
    echo "✅ TEST PASSED: Directory pattern functionality confirmed."
    
    cd /
    return 0
  }
  
  local test_functions=(
    "testDirectoryPattern"
  )
  
  local ignored_tests=()
  
  bashTestRunner test_functions ignored_tests
  local result=$?
  
  return $result
}
