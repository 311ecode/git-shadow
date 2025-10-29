# Git Shadow README

## Overview

Git Shadow is a set of shell scripts designed to manage a secondary "shadow" branch in a Git repository. This shadow branch is used to track and manage files that are ignored by the main `.gitignore` file. The primary use case is to handle sensitive or large files that should not be committed to the main branch but need to be version-controlled.

## Getting Started

### Prerequisites

- Git must be installed on your system.
- A Git repository must be initialized in the directory where you plan to use Git Shadow.

### Installation

1. Clone the Git repository containing the Git Shadow scripts.
2. Source the scripts in your shell configuration file (e.g., `.bashrc`, `.zshrc`).

Example for `.bashrc`:
```bash
source /path/to/git-shadow-scripts/git-shadow-init.sh
source /path/to/git-shadow-scripts/git-shadow-add.sh
source /path/to/git-shadow-scripts/git-shadow-pull.sh
source /path/to/git-shadow-scripts/git-shadow-push.sh
```

### Initialize Git Shadow

Run the following command to initialize Git Shadow in your repository:
```bash
git-shadow-init
```

This command will:
- Check if the shadow branch exists on the remote.
- If it doesn't exist, it will create and push a new shadow branch with a default configuration file.

### Adding Files to the Shadow Config

To add a file or directory to the shadow config, use the following command:
```bash
git-shadow-add <path-to-file-or-dir>
```

- `<path-to-file-or-dir>`: The relative path to the file or directory you want to add to the shadow config. This path should be relative to the root of the Git repository.

### Pulling Files from the Shadow Branch

To pull files from the shadow branch into your working directory, use the following command:
```bash
git-shadow-pull
```

This command will:
- Clone the shadow branch to a temporary directory.
- Read the shadow config file and restore the listed files from the shadow branch to your working directory.

### Pushing Files to the Shadow Branch

To push changes from your working directory to the shadow branch, use the following command:
```bash
git-shadow-push
```

This command will:
- Clone the shadow branch to a temporary directory.
- Read the shadow config file and sync the listed files from your working directory to the shadow branch.
- Commit and push the changes to the remote shadow branch.

### Using -h and --help

For detailed help on any command, use the `-h` or `--help` option. This feature is managed at an upper layer and provides detailed usage instructions for each command.

## Advanced Usage

### Configuration

The Git Shadow scripts use the following configuration variables:
- `GIT_SHADOW_BRANCH`: The name of the shadow branch (default: `shadow`).
- `GIT_SHADOW_CONFIG_FILE`: The name of the shadow config file (default: `.git-shadow-config`).
- `GIT_SHADOW_REMOTE`: The name of the remote repository (default: `origin`).

These variables can be overridden by setting environment variables or modifying the scripts directly.

### Directory Structure

If the functionality of Git Shadow grows significantly, consider organizing the scripts into directories. For example:
```
git-shadow/
├── git-shadow-init.sh
├── git-shadow-add.sh
├── git-shadow-pull.sh
└── git-shadow-push.sh
```

This structure helps maintain readability and organization as the project evolves.

## Troubleshooting

- Ensure that the files you want to add to the shadow config are ignored by your main `.gitignore` file.
- Verify that the remote repository URL is correctly configured in your Git settings.
- Check for any errors in the shell scripts and ensure they have the correct permissions to execute.

## Contributing

Contributions to Git Shadow are welcome. Please follow the existing code style and ensure that any new functionality is well-documented.

## License

Git Shadow is licensed under the MIT License. See the LICENSE file for details.
