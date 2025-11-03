#!/bin/bash
git_shadow_get_repo_url() {
    git config --get "remote.${GIT_SHADOW_REMOTE}.url"
}