#!/usr/bin/env bash
# @file testGitShadowExponentialNestingBug.sh
# @brief Test that catches the exponential directory nesting bug
# @description This test does multiple push/pull cycles to catch the nesting bug

testGitShadowExponentialNestingBug() {
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
  
  local REPO_NAME="git-shadow-nesting-test-$(date +%s)-$$"
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
  
  testExponentialNesting() {
    echo ""
    echo "🐛 Integration Test: Exponential Directory Nesting Bug"
    echo "======================================================"
    echo ""
    echo "This test reproduces the exponential nesting bug by:"
    echo "  1. Creating ai-chat-data/ with files"
    echo "  2. Pushing to shadow"
    echo "  3. Deleting local copy"
    echo "  4. Pulling from shadow"
    echo "  5. Pushing again (captures any nesting)"
    echo "  6. Pulling again (exponential growth!)"
    echo "  7. Verifying NO nesting occurred"
    
    # ============================================================
    # Step 1: Create GitHub repository
    # ============================================================
    echo ""
    echo "STEP 1: Creating GitHub repository"
    echo "-----------------------------------"
    
    REPO_URL=$(github_pusher_create_repo \
      "$GITHUB_OWNER" \
      "$REPO_NAME" \
      "git-shadow nesting bug test" \
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
    
    # Create nested structure
    mkdir -p projects/data/ai-chat-data
    echo "Original content" > projects/data/ai-chat-data/info.txt
    echo "Session data" > projects/data/ai-chat-data/session.log
    
    # Create .gitignore WITHOUT trailing slash (triggers the bug)
    cat > .gitignore << 'EOF'
ai-chat-data
.git-shadow-config
EOF
    
    git add .gitignore
    git commit -q -m "Initial commit"
    git push -q origin master
    
    echo "✅ Repository initialized"
    echo ""
    echo "📂 Initial structure:"
    tree -a -I '.git' projects 2>/dev/null || find projects -type f | sort
    
    # ============================================================
    # Step 3: Initialize git-shadow
    # ============================================================
    echo ""
    echo "STEP 3: Initializing git-shadow"
    echo "--------------------------------"
    
    git-shadow-init 2>&1 | grep -v "^Checking\|^Shadow\|^Initialization\|^Reminder" | head -5
    echo "✅ git-shadow initialized"
    
    # ============================================================
    # Step 4: Add pattern and FIRST PUSH
    # ============================================================
    echo ""
    echo "STEP 4: First push to shadow"
    echo "-----------------------------"
    
    git-shadow-add "ai-chat-data" 2>&1 | grep -q "Successfully added"
    echo "✅ Pattern added"
    
    echo ""
    echo "Running first git-shadow-push..."
    git-shadow-push 2>&1 | tail -3
    echo "✅ First push complete"
    
    # Count files in shadow
    local SHADOW_CHECK_DIR="${TEST_ROOT}/shadow-check-1"
    git clone -q --depth 1 --branch shadow "$GIT_REMOTE_URL" "$SHADOW_CHECK_DIR" 2>/dev/null
    local files_after_push1
    files_after_push1=$(find "$SHADOW_CHECK_DIR/projects" -type f 2>/dev/null | wc -l)
    echo "📊 Files in shadow after push #1: $files_after_push1"
    
    # ============================================================
    # Step 5: Delete and FIRST PULL
    # ============================================================
    echo ""
    echo "STEP 5: Delete local and first pull"
    echo "------------------------------------"
    
    rm -rf projects/data/ai-chat-data
    echo "🗑️  Deleted local ai-chat-data/"
    
    echo ""
    echo "Running first git-shadow-pull..."
    git-shadow-pull 2>&1 | grep "Restoring:"
    echo "✅ First pull complete"
    
    # Check for nesting after first pull
    if [[ -d "projects/data/ai-chat-data/ai-chat-data" ]]; then
      echo ""
      echo "🐛 BUG DETECTED AFTER FIRST PULL!"
      echo "   Nesting occurred: projects/data/ai-chat-data/ai-chat-data/ exists"
      tree -a projects/data/ai-chat-data 2>/dev/null || find projects/data/ai-chat-data | sort
      cd /
      return 1
    fi
    
    echo "✅ No nesting after first pull"
    
    local files_after_pull1
    files_after_pull1=$(find projects/data/ai-chat-data -type f 2>/dev/null | wc -l)
    echo "📊 Files in local after pull #1: $files_after_pull1"
    
    # ============================================================
    # Step 6: SECOND PUSH (captures any nesting)
    # ============================================================
    echo ""
    echo "STEP 6: Second push to shadow"
    echo "------------------------------"
    
    echo "Running second git-shadow-push..."
    git-shadow-push 2>&1 | tail -3
    echo "✅ Second push complete"
    
    # Count files in shadow
    local SHADOW_CHECK_DIR2="${TEST_ROOT}/shadow-check-2"
    git clone -q --depth 1 --branch shadow "$GIT_REMOTE_URL" "$SHADOW_CHECK_DIR2" 2>/dev/null
    local files_after_push2
    files_after_push2=$(find "$SHADOW_CHECK_DIR2/projects" -type f 2>/dev/null | wc -l)
    echo "📊 Files in shadow after push #2: $files_after_push2"
    
    if [[ "$files_after_push2" -ne "$files_after_push1" ]]; then
      echo ""
      echo "🐛 BUG DETECTED: File count changed!"
      echo "   Push #1: $files_after_push1 files"
      echo "   Push #2: $files_after_push2 files"
      echo ""
      echo "Shadow structure after push #2:"
      (cd "$SHADOW_CHECK_DIR2" && tree -a projects 2>/dev/null || find projects | sort)
      cd /
      return 1
    fi
    
    echo "✅ File count unchanged after second push"
    
    # ============================================================
    # Step 7: Delete and SECOND PULL (exponential growth test)
    # ============================================================
    echo ""
    echo "STEP 7: Delete local and second pull (exponential test)"
    echo "--------------------------------------------------------"
    
    rm -rf projects/data/ai-chat-data
    echo "🗑️  Deleted local ai-chat-data/ again"
    
    echo ""
    echo "Running second git-shadow-pull..."
    git-shadow-pull 2>&1 | grep "Restoring:"
    echo "✅ Second pull complete"
    
    # THE CRITICAL CHECK: Look for exponential nesting
    if [[ -d "projects/data/ai-chat-data/ai-chat-data" ]]; then
      echo ""
      echo "🐛 BUG DETECTED AFTER SECOND PULL!"
      echo "   Exponential nesting occurred!"
      echo ""
      echo "Structure:"
      tree -a projects/data/ai-chat-data 2>/dev/null || find projects/data/ai-chat-data | sort
      cd /
      return 1
    fi
    
    echo "✅ No nesting after second pull"
    
    local files_after_pull2
    files_after_pull2=$(find projects/data/ai-chat-data -type f 2>/dev/null | wc -l)
    echo "📊 Files in local after pull #2: $files_after_pull2"
    
    if [[ "$files_after_pull2" -ne "$files_after_pull1" ]]; then
      echo ""
      echo "🐛 BUG DETECTED: File count changed after second pull!"
      echo "   Pull #1: $files_after_pull1 files"
      echo "   Pull #2: $files_after_pull2 files"
      cd /
      return 1
    fi
    
    echo "✅ File count unchanged"
    
    # ============================================================
    # Step 8: THIRD CYCLE (paranoid check)
    # ============================================================
    echo ""
    echo "STEP 8: Third cycle (paranoid exponential growth check)"
    echo "-------------------------------------------------------"
    
    echo "Running third git-shadow-push..."
    git-shadow-push 2>&1 | tail -3
    
    rm -rf projects/data/ai-chat-data
    
    echo "Running third git-shadow-pull..."
    git-shadow-pull 2>&1 | grep "Restoring:"
    
    # Final check
    if [[ -d "projects/data/ai-chat-data/ai-chat-data" ]]; then
      echo ""
      echo "🐛 BUG DETECTED AFTER THIRD CYCLE!"
      echo "   Exponential nesting occurred after multiple cycles!"
      tree -a projects/data/ai-chat-data 2>/dev/null || find projects/data/ai-chat-data | sort
      cd /
      return 1
    fi
    
    local files_after_pull3
    files_after_pull3=$(find projects/data/ai-chat-data -type f 2>/dev/null | wc -l)
    echo "📊 Files in local after pull #3: $files_after_pull3"
    
    if [[ "$files_after_pull3" -ne 2 ]]; then
      echo ""
      echo "🐛 BUG DETECTED: Expected 2 files, found $files_after_pull3"
      echo ""
      echo "All files:"
      find projects/data/ai-chat-data -type f | sort
      cd /
      return 1
    fi
    
    echo "✅ No exponential growth after 3 cycles"
    
    # ============================================================
    # Final Verification
    # ============================================================
    echo ""
    echo "STEP 9: Final verification"
    echo "--------------------------"
    
    echo "📂 Final structure:"
    tree -a projects/data/ai-chat-data 2>/dev/null || find projects/data/ai-chat-data | sort
    
    echo ""
    echo "✅ TEST PASSED: No exponential nesting bug detected!"
    echo "   - 3 push/pull cycles completed"
    echo "   - File count remained stable: 2 files"
    echo "   - No ai-chat-data/ai-chat-data/ nesting"
    echo "   - No exponential growth"
    
    cd /
    return 0
  }
  
  local test_functions=(
    "testExponentialNesting"
  )
  
  local ignored_tests=()
  
  bashTestRunner test_functions ignored_tests
  local result=$?
  
  return $result
}
