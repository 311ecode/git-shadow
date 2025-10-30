#!/usr/bin/env bash
# @file testGitShadowGithubIntegration.sh
# @brief Integration test for git-shadow using real GitHub repositories
# @description Tests the duplication bug: ai-chat-data/ getting nested after pull

testGitShadowGithubIntegration() {
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
  
  local REPO_NAME="git-shadow-test-$(date +%s)-$$"
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
  
  testNestedPathBugWithGithub() {
    echo ""
    echo "🐛 Integration Test: Nested Path Bug (Real-world scenario)"
    echo "=========================================================="
    echo ""
    echo "This test reproduces the bug where:"
    echo "  - Deep nested paths like projects/screentoai/server/scripts/tclom/ai-chat-data/"
    echo "  - Only 'ai-chat-data/' is in .gitignore (ignores at any level)"
    echo "  - Parent directories ARE tracked on main branch"
    echo "  - Pull should restore ai-chat-data but warns about parents"
    
    # ============================================================
    # Step 1: Create GitHub repository
    # ============================================================
    echo ""
    echo "STEP 1: Creating GitHub repository"
    echo "-----------------------------------"
    
    REPO_URL=$(github_pusher_create_repo \
      "$GITHUB_OWNER" \
      "$REPO_NAME" \
      "git-shadow integration test repository" \
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
    # Step 2: Set up local repository with REALISTIC structure
    # ============================================================
    echo ""
    echo "STEP 2: Setting up realistic project structure"
    echo "-----------------------------------------------"
    
    local LOCAL_DIR="${TEST_ROOT}/local"
    mkdir -p "$LOCAL_DIR"
    cd "$LOCAL_DIR" || return 1
    
    git init -q
    git config user.email "test@example.com"
    git config user.name "Git Shadow Test"
    git remote add origin "$GIT_REMOTE_URL"
    
    # Create deep nested structure matching real scenario
    mkdir -p projects/screentoai/server/scripts/tclom
    
    # Add tracked files in parent directories
    echo "# Project README" > projects/README.md
    echo "# Server README" > projects/screentoai/server/README.md
    echo "#!/bin/bash" > projects/screentoai/server/scripts/tclom/run.sh
    
    # Create ai-chat-data directory with files (this will be ignored)
    mkdir -p projects/screentoai/server/scripts/tclom/ai-chat-data
    echo "Chat conversation 1" > projects/screentoai/server/scripts/tclom/ai-chat-data/info.txt
    echo "Chat conversation 2" > projects/screentoai/server/scripts/tclom/ai-chat-data/session.log
    
    # Create .gitignore that ignores ONLY ai-chat-data at any level
    cat > .gitignore << 'EOF'
ai-chat-data/
.git-shadow-config
EOF
    
    echo "✅ Local repository initialized"
    echo ""
    echo "📂 Project structure:"
    tree -a -I '.git' 2>/dev/null || find . -not -path "./.git/*" -not -path "./.git" | sort
    
    # Commit tracked files
    git add .
    git commit -q -m "Initial commit with tracked parent directories"
    git push -q origin master
    
    echo ""
    echo "✅ Parent directories are tracked on master branch"
    echo "✅ ai-chat-data/ is ignored (not tracked)"
    
    # ============================================================
    # Step 3: Initialize git-shadow
    # ============================================================
    echo ""
    echo "STEP 4: Initializing git-shadow"
    echo "--------------------------------"
    
    if ! git-shadow-init 2>&1 | grep -v "^Checking\|^Shadow\|^Initialization\|^Reminder"; then
      echo "❌ ERROR: git-shadow-init failed"
      cd /
      return 1
    fi
    
    echo "✅ git-shadow initialized"
    
    # ============================================================
    # Step 5: Add pattern and push to shadow
    # ============================================================
    echo ""
    echo "STEP 4: Adding ai-chat-data pattern and pushing"
    echo "------------------------------------------------"
    
    if ! git-shadow-add "ai-chat-data" 2>&1 | grep -q "Successfully added"; then
      echo "❌ ERROR: git-shadow-add failed"
      cd /
      return 1
    fi
    
    echo "✅ Pattern added to shadow config"
    
    echo ""
    echo "Running git-shadow-push..."
    git-shadow-push
    
    if [[ $? -ne 0 ]]; then
      echo "❌ ERROR: git-shadow-push failed"
      cd /
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
    
    echo "📊 Shadow branch structure:"
    (cd "$SHADOW_CHECK_DIR" && tree -a -I '.git' 2>/dev/null || find . -not -path "./.git/*" -not -path "./.git" | sort)
    
    local shadow_file_count
    shadow_file_count=$(find "$SHADOW_CHECK_DIR/projects" -type f 2>/dev/null | wc -l)
    echo ""
    echo "Files in shadow (under projects/): $shadow_file_count"
    
    # ============================================================
    # Step 6: Delete local ai-chat-data directory
    # ============================================================
    echo ""
    echo "STEP 6: Deleting local ai-chat-data/ directory"
    echo "-----------------------------------------------"
    
    cd "$LOCAL_DIR" || return 1
    rm -rf projects/screentoai/server/scripts/tclom/ai-chat-data
    
    echo "✅ Deleted ai-chat-data/"
    echo ""
    echo "📂 Structure before pull:"
    tree -a -I '.git' 2>/dev/null || find projects -type f | sort
    
    # ============================================================
    # Step 7: Pull from shadow (THE BUG TEST)
    # ============================================================
    echo ""
    echo "STEP 7: Pulling from shadow branch"
    echo "-----------------------------------"
    echo "Expected behavior:"
    echo "  - Should restore projects/.../ai-chat-data/"
    echo "  - Should warn about parent dirs (they're tracked)"
    echo "  - Should NOT skip ai-chat-data (it's ignored)"
    echo ""
    echo "🔍 Checking .gitignore status of ai-chat-data:"
    echo "  Testing: projects/screentoai/server/scripts/tclom/ai-chat-data"
    if git check-ignore -q "projects/screentoai/server/scripts/tclom/ai-chat-data"; then
      echo "  ✅ Directory is ignored (will be restored)"
    else
      echo "  ❌ Directory is NOT ignored (will be skipped)"
    fi
    echo "  Testing: projects/screentoai/server/scripts/tclom/ai-chat-data/info.txt"
    if git check-ignore -q "projects/screentoai/server/scripts/tclom/ai-chat-data/info.txt"; then
      echo "  ✅ File is ignored (will be restored)"
    else
      echo "  ❌ File is NOT ignored (will be skipped)"
    fi
    echo ""
    
    git-shadow-pull 2>&1 | tee "${TEST_ROOT}/pull-output.log"
    
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
      echo "❌ ERROR: git-shadow-pull failed"
      cd /
      return 1
    fi
    
    echo ""
    echo "✅ Pull completed"
    
    # ============================================================
    # Step 8: VERIFICATION - Check for bugs
    # ============================================================
    echo ""
    echo "STEP 8: Verification - Checking for bugs"
    echo "-----------------------------------------"
    
    echo "📂 Structure after pull:"
    tree -a -I '.git' 2>/dev/null || find projects -type f 2>/dev/null | sort
    
    echo ""
    echo "🔍 Detailed inspection of ai-chat-data directory:"
    if command -v tree >/dev/null 2>&1; then
      tree -a "projects/screentoai/server/scripts/tclom/ai-chat-data" 2>/dev/null || true
    else
      find "projects/screentoai/server/scripts/tclom/ai-chat-data" 2>/dev/null | sort
    fi
    
    local pulled_file_count
    pulled_file_count=$(find projects/screentoai/server/scripts/tclom/ai-chat-data -type f 2>/dev/null | wc -l)
    
    echo ""
    echo "📊 File counts:"
    echo "   In shadow: $shadow_file_count"
    echo "   After pull: $pulled_file_count"
    
    # Check 1: ai-chat-data should be restored
    if [[ ! -f "projects/screentoai/server/scripts/tclom/ai-chat-data/info.txt" ]]; then
      echo ""
      echo "❌ BUG FOUND: Expected file missing!"
      echo "   projects/screentoai/server/scripts/tclom/ai-chat-data/info.txt not found"
      echo ""
      echo "This means git-shadow-pull is incorrectly skipping ignored directories"
      echo "when their parent paths are tracked!"
      cd /
      return 1
    fi
    
    echo "✅ ai-chat-data/info.txt correctly restored"
    
    # Check 2: THE CRITICAL BUG CHECK - No nested duplication
    if [[ -d "projects/screentoai/server/scripts/tclom/ai-chat-data/ai-chat-data" ]]; then
      echo ""
      echo "🐛 BUG FOUND: Nested duplicate directory!"
      echo "   projects/screentoai/server/scripts/tclom/ai-chat-data/ai-chat-data/ exists"
      echo ""
      echo "Expected structure:"
      echo "  ai-chat-data/"
      echo "  ├── info.txt"
      echo "  └── session.log"
      echo ""
      echo "Actual structure:"
      tree -a "projects/screentoai/server/scripts/tclom/ai-chat-data" 2>/dev/null || \
        find "projects/screentoai/server/scripts/tclom/ai-chat-data" -type f | sort | sed 's/^/  /'
      cd /
      return 1
    fi
    
    echo "✅ No nested duplication (ai-chat-data/ai-chat-data/ does NOT exist)"
    
    # Check 3: File count should match EXACTLY (critical for detecting duplication)
    if [[ "$pulled_file_count" -ne "$shadow_file_count" ]]; then
      echo ""
      echo "🐛 BUG FOUND: File count mismatch!"
      echo "   Expected $shadow_file_count files, got $pulled_file_count"
      echo ""
      echo "This indicates duplication or missing files."
      echo "All files found:"
      find "projects/screentoai/server/scripts/tclom/ai-chat-data" -type f | sort | sed 's/^/  /'
      cd /
      return 1
    fi
    
    echo "✅ File count matches exactly"
    
    # Check 4: Verify BOTH files exist at correct location
    if [[ ! -f "projects/screentoai/server/scripts/tclom/ai-chat-data/info.txt" ]]; then
      echo ""
      echo "❌ ERROR: info.txt missing at correct location!"
      cd /
      return 1
    fi
    
    if [[ ! -f "projects/screentoai/server/scripts/tclom/ai-chat-data/session.log" ]]; then
      echo ""
      echo "❌ ERROR: session.log missing at correct location!"
      cd /
      return 1
    fi
    
    echo "✅ Both files exist at correct location"
    
    # Check 5: Verify content
    if ! grep -q "Chat conversation 1" "projects/screentoai/server/scripts/tclom/ai-chat-data/info.txt"; then
      echo ""
      echo "❌ ERROR: File content mismatch!"
      cd /
      return 1
    fi
    
    echo "✅ File content verified"
    
    # Check 6: Parent directories should still be tracked
    git ls-files | grep -q "projects/screentoai/server/README.md"
    if [[ $? -ne 0 ]]; then
      echo ""
      echo "❌ ERROR: Parent directories were modified!"
      cd /
      return 1
    fi
    
    echo "✅ Parent directories still tracked correctly"
    
    # Check 7: FINAL PARANOID CHECK - Count all files recursively
    local total_files_in_ai_chat_data
    total_files_in_ai_chat_data=$(find "projects/screentoai/server/scripts/tclom/ai-chat-data" -type f | wc -l)
    
    if [[ "$total_files_in_ai_chat_data" -ne 2 ]]; then
      echo ""
      echo "🐛 BUG FOUND: Expected exactly 2 files, found $total_files_in_ai_chat_data"
      echo "This indicates duplication!"
      echo ""
      echo "All files in ai-chat-data:"
      find "projects/screentoai/server/scripts/tclom/ai-chat-data" -type f | sort | sed 's/^/  /'
      cd /
      return 1
    fi
    
    echo "✅ Exactly 2 files in ai-chat-data (no hidden duplicates)"
    
    echo ""
    echo "✅ TEST PASSED: All checks passed!"
    echo "   - ai-chat-data correctly restored despite parent warnings"
    echo "   - No duplication (ai-chat-data/ai-chat-data/ does NOT exist)"
    echo "   - File counts match exactly (2 files, no more, no less)"
    echo "   - Parent directories intact"
    
    cd /
    return 0
  }
  
  local test_functions=(
    "testNestedPathBugWithGithub"
  )
  
  local ignored_tests=()
  
  bashTestRunner test_functions ignored_tests
  local result=$?
  
  return $result
}