# git-shadow

## 💡 Overview

`git-shadow` is a set of shell functions designed to manage a secondary "shadow" branch within your main Git repository.

This shadow branch is used to version-control project-relevant artifacts that are (and should be) ignored by your main `.gitignore`. This includes things like:

* **Large data files**
* **Long chat histories** or AI conversations
* **Environment-specific configuration**
* Other contextual data you want to save but keep out of your main code history.

It works by tracking **filename patterns**, not specific paths. This allows you to add a pattern like `ai-chat-data` and have `git-shadow` automatically find and sync all `ai-chat-data` directories from *any* location in your project.

## ✨ Core Concept

The logic is designed to be simple, safe, and powerful:

1.  **`git-shadow-add <pattern>`**
    * You add a *pattern* (e.g., `ai-chat-data` or `*.log`) to the `.git-shadow-config` file.
    * You **do not** add a specific path like `src/ai-chat-data`.

2.  **`git-shadow-push`**
    * The script reads each pattern from the config.
    * It **finds** all files/dirs in your working directory that match those patterns (e.g., it finds `src/ai-chat-data` and `lib/ai-chat-data`).
    * It copies all found items that are **currently ignored** by your `.gitignore` to the `shadow` branch, preserving their full directory structure.

3.  **`git-shadow-pull`**
    * The script finds **all** files and directories stored in the `shadow` branch.
    * It restores each one to its original path in your working directory, **only if** that path is **currently ignored** by your `.gitignore`.
    * This provides a critical safety-check and prevents `git-shadow` from ever overwriting a file that is tracked on your current branch.

### 🚚 Automatic "Move" Detection

This pattern-based logic automatically handles moved files.
* You move `src/ai-chat-data` to `new/location/ai-chat-data`.
* You run `git-shadow-push`.
* The script's "find" command no longer finds the old path but discovers the new one.
* In the `shadow` branch, this is automatically recorded as a "delete" at the old path and an "add" at the new path. No extra commands are needed.

---

## 🚀 Getting Started

### Prerequisites

* Git must be installed.
* You must be inside an initialized Git repository.

### Installation

1.  Source the loader file your shell configuration file (e.g., `.bashrc`, `.zshrc`).

2.  Restart your shell or run `source ~/.bashrc`.

-----

## 🛠️ Commands

### 1\. `git-shadow-init`

Initializes `git-shadow` in your repository.

```bash
git-shadow-init
```

This command will:

  * Check if the `shadow` branch exists on the `origin` remote.
  * If not, it will create and push a new, empty `shadow` branch containing only the `.git-shadow-config` file.

### 2\. `git-shadow-add <pattern>`

Adds a new filename pattern to the shadow config.

```bash
# Example 1: Track all directories named 'ai-chat-data'
git-shadow-add "ai-chat-data"

# Example 2: Track all files ending in .log
git-shadow-add "*.log"
```

This command adds the literal string (e.g., `"ai-chat-data"`) as a new line in the `.git-shadow-config` file and pushes the change.

### 3\. `git-shadow-push`

Finds and saves all ignored files matching the config patterns.

```bash
git-shadow-push
```

This command will:

1.  Read all patterns from `.git-shadow-config` (e.g., `ai-chat-data`).
2.  Run a "find" command to locate all matching files/dirs in your project.
3.  Copy all found items that are **ignored by your current `.gitignore`** to a temporary clone.
4.  Commit and push this new "snapshot" of files to the `shadow` branch.

### 4\. `git-shadow-pull`

Restores all files from the shadow branch.

```bash
git-shadow-pull
```

This command will:

1.  Clone the `shadow` branch to a temporary directory.
2.  Find **all** files within that clone (e.g., `src/ai-chat-data`, `lib/ai-chat-data`, `src/secrets.env`).
3.  For each file, it performs a **safety check**:
      * **If** the file's path (e.g., `src/ai-chat-data`) is **ignored** by your current branch's `.gitignore`, it is safely restored.
      * **If** the file's path is **NOT ignored** (e.g., you're on a branch where `src/secrets.env` is tracked), it will **skip** restoring that file and print a warning.

-----

## ⚙️ Configuration

The `git-shadow` scripts use the following internal variables. You can edit the scripts to change them.

  * `GIT_SHADOW_BRANCH`: The name of the shadow branch (default: `shadow`).
  * `GIT_SHADOW_CONFIG_FILE`: The config file name (default: `.git-shadow-config`).
  * `GIT_SHADOW_REMOTE`: The name of the remote (default: `origin`).

## ⚠️ Troubleshooting

  * **Rule \#1:** For `push` or `pull` to work on a file, it **must** be matched by your main `.gitignore` file. The safety checks will prevent any action on non-ignored files.
  * When you run `git-shadow-init`, you may want to run `git-shadow-add ".git-shadow-config"` and add `.git-shadow-config` to your main `.gitignore` so you can `pull` the config file itself.
  * Verify that your remote (`origin`) is set up and accessible.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

