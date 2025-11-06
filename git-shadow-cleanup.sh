git-shadow-cleanup() {
    local GIT_SHADOW_TEMP_DIR="${GIT_SHADOW_TEMP_DIR:-/tmp/git-shadow}"
    
    if [ -d "$GIT_SHADOW_TEMP_DIR" ]; then
        echo "Cleaning up git-shadow temporary directories..."
        rm -rf "$GIT_SHADOW_TEMP_DIR"
        echo "Temporary directories removed from: $GIT_SHADOW_TEMP_DIR"
    else
        echo "No git-shadow temporary directories found at: $GIT_SHADOW_TEMP_DIR"
    fi
}

git-shadow-list-temp() {
    local GIT_SHADOW_TEMP_DIR="${GIT_SHADOW_TEMP_DIR:-/tmp/git-shadow}"
    
    if [ -d "$GIT_SHADOW_TEMP_DIR" ]; then
        echo "Git-shadow temporary directories:"
        find "$GIT_SHADOW_TEMP_DIR" -type d -name "*-*" 2>/dev/null | sort
    else
        echo "No git-shadow temporary directories found at: $GIT_SHADOW_TEMP_DIR"
    fi
}
