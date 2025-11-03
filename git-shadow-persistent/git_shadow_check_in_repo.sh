#!/bin/bash
git_shadow_check_in_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { 
        echo "Error: This command must be run inside a Git repository." >&2
        return 1
    }
}