#!/bin/bash
# Persistent shadow branch management for git-shadow

# --- Configuration ---
GIT_SHADOW_BRANCH="shadow"
GIT_SHADOW_CONFIG_FILE=".git-shadow-config"
GIT_SHADOW_REMOTE="origin"
GIT_SHADOW_TEMP_DIR="${GIT_SHADOW_TEMP_DIR:-/tmp/git-shadow}"
GIT_SHADOW_PERSISTENT_DIR="${GIT_SHADOW_TEMP_DIR}/persistent-shadow"

# --- Helper Functions ---