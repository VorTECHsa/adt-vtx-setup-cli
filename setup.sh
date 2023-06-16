#!/usr/bin/env bash

# ==========================================================
# == Args & Constants                                     ==
# ==========================================================

# -- Args
WORKFLOW=$1

# -- Constants
REPOS_DIR="$HOME/workspace"
SSH_DIR="$HOME/.ssh"
SSH_KEY_FILE="$SSH_DIR/id_ed25519"
GITHUB_REPOS_SSH_PREFIX="git@github.com:VorTECHsa"
# Token that is used as a prefix for any content added to any files
# such as .zprofile, such that we know if we should add content to them.
# This keeps the script idempotent (re-runnable without bad affects).
ADDED_BY_US_TOKEN="# -- Added by vcli"

# ==========================================================
# == General configuration (for all workflows)            ==
# ==========================================================

# General Homebrew apps to install for any workflow
GENERAL_HOMEBREW_CASK_APPS=("visual-studio-code" "insomnia" "cyberduck" "google-chrome")
GENERAL_HOMEBREW_NON_CASK_APPS=("awscli" "sops")

GENERAL_ALIASES="# General Conveniences
alias c='clear'
alias cls='clear'

# Git
alias gs='git status'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gc='git commit'
alias gcm='git commit -m'
alias gm='git merge'
alias gp='git push'
alias gf='git fetch'
alias gp='git push'
alias gl='git pull'"

# ==========================================================
# == Workflow-specific configuration                      ==
# ==========================================================
# The supported workflows. Add to this when more workflows are desired.
SUPPORTED_WORKFLOWS=("adt")

# --------------------------------------
# -- ADT workflow configuration       --
# --------------------------------------
ADT_REPOS_DIR="$REPOS_DIR/adt"
ADT_WORKFLOW_REPOS=("web" "api" "app-core" "adt-publish-workers")
ADT_WORKFLOW_HOMEBREW_CASK_APPS=("obs" "hex-fiend" "pgadmin4")

# ==========================================================
# == Functions                                            ==
# ==========================================================

# Concatenates the given `strings` list into a comma-seperated list string.
concatenate_strings() {
  local strings=("$@")  # Store the input strings in an array
  local result=""

  for ((i=0; i<${#strings[@]}; i++)); do
    result+="${strings[i]}"
    if (( i < ${#strings[@]}-1 )); then
      result+=", "
    fi
  done

  echo "$result"
}

# Returns 1 if the given `value` is in the given `values` list, 0 otherwise.
check_value_in_list() {
  local value="$1"
  shift
  local values=("$@")

  for val in "${values[@]}"; do
    if [[ "$val" == "$value" ]]; then
      return 1
    fi
  done

  return 0
}

# Ensures that the given `dir` exists, using `friendly_name` as a friendly descriptor.
ensure_dir_exists() {
  local dir="$1"
  local friendly_name="$2"

  echo "\n==> Ensuring $friendly_name dir $dir exists."
  if [ ! -d "$dir" ]; then
    echo "--> $friendly_name dir $dir does not exist; creating."
    mkdir -p "$dir"
  else
    echo "[i] $friendly_name dir $ADT_REPOS_DIR already exists; skipping."
  fi
}

# Ensures that the given `file` exists and contains the given `text`, using the given `token` as a test.
add_text_if_not_exists() {
  local file="$1"
  local text="$2"
  local token="$3"

  local textToAdd="\n\n$token\n$text"

  echo "--> Checking if $file already exists"
  if [ ! -e "$file" ]; then
    echo "--> $file does not exist; creating with text."
    mkdir -p "$(dirname "$file")"
    echo "$textToAdd" > "$file"
    return
  fi

  echo "--> $file exists; checking if it already contains token."
  if ! grep -qF "$token" "$file"; then
    echo "--> $file does not contain token; adding text."
    echo "$textToAdd" >> "$file"
  else
    echo "--> $file already contains token; skipping."
  fi
}

# Clones the given `repo` from VorTECHsa GitHub (for the CWD).
clone_repo_if_not_exists() {
  local repo="$1"

  echo "--> Checking if $repo repository dir already exists."
  if [ ! -d "$ADT_REPOS_DIR/$repo" ]; then
    echo "--> $repo repository dir does not exist; cloning."
    git clone $GITHUB_REPOS_SSH_PREFIX/$repo
  else
    echo "--> $repo repository dir already exists; skipping."
  fi
}

# Clones the given `repos` list from VorTECHsa GitHub (for the CWD).
clone_repos_if_not_exists() {
  local repo_names=("$@")

  for repo_name in "${repo_names[@]}"; do
    clone_repo_if_not_exists "$repo_name"
  done
}

# Installs the given Homebrew package (cask), if it hasn't already been installed.
install_homebrew_cask_package() {
  local package="$1"
  
  if brew list "$package" >/dev/null 2>&1; then
    echo "--> App '$package' is already installed; skipping."
  else
    echo "--> App '$package' is not installed; installing."
    if [ "$DISABLE_LONG_RUNNERS" != "1" ]; then
      brew install --cask "$package"
    else
      echo "[i] DISABLE_LONG_RUNNERS is set. Skipping installation of $package"
    fi
  fi
}

# Installs the given Homebrew package (non-cask), if it hasn't already been installed.
install_homebrew_non_cask_package() {
  local package="$1"
  
  if brew list "$package" >/dev/null 2>&1; then
    echo "--> App '$package' is already installed; skipping."
  else
    echo "--> App '$package' is not installed; installing."
    if [ "$DISABLE_LONG_RUNNERS" != "1" ]; then
      brew install "$package"
    else
      echo "[i] DISABLE_LONG_RUNNERS is set. Skipping installation of $package"
    fi
  fi
}

install_homebrew_non_cask_packages() {
  local packages=("$@")
  for package in "${packages[@]}"; do
    install_homebrew_non_cask_package "$package"
  done
}

install_homebrew_cask_packages() {
  local packages=("$@")
  for package in "${packages[@]}"; do
    install_homebrew_cask_package "$package"
  done
}

# ==========================================================
# == CLI functionality (arg validation, help page, etc.)  ==
# ==========================================================

supported_workflows_str=$(concatenate_strings "${SUPPORTED_WORKFLOWS[@]}")
USAGE="Usage: sh setup.sh <workflow>

<workflow> - Optional workflow to enable. Possible values: $supported_workflows_str

sh setup.sh --help - show this usage help text"

# Print help screen and exit if first param is "help"-like
if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "help" ] || [ "$1" == "h" ]; then
  echo "$USAGE"
  exit 0
fi

# If the workflow arg has been supplied, then check it's validity
if [ ! -z "$1" ]; then
  check_value_in_list "$1" "${SUPPORTED_WORKFLOWS[@]}"
  if [ $? -eq 0 ]; then
    echo "Error: Workflow '$1' is not supported. It must be one of: $supported_workflows_str\n"
    echo "$USAGE"
    exit 1
  fi
else
  echo "WARN: <workflow> argument has not been supplied. This means a general-only setup will be performed."
  echo "      Run with '--help' for more information"
  echo
  echo "      If this is okay, press 'Enter' to proceed, or any other character to abort."
  read -n 1 input
  if [[ $input != "" ]]; then
    echo "Exiting."
    exit 0
  else
    echo "[i] Proceeding."
  fi
fi

# ==========================================================
# == SSH key setup and GitHub SSH configuration           ==
# ==========================================================

# Create a new ed25519 ssh key if it hasn't already been created
echo "\n==> Ensuring ssh key "$SSH_KEY_FILE" exists."
if [ ! -e "$SSH_KEY_FILE" ]; then
  # Read in email to use for the ssh key
  echo "SSH Key Email":
  read EMAIL
  # Read in passphrase to use for the ssh key
  echo "SSH Key Passphrase": 
  read -s PASSPHRASE
  echo "--> ssh key "$SSH_KEY_FILE" does not exist; creating for $EMAIL."
  echo "\n" | ssh-keygen -t ed25519 -C $EMAIL -P "$PASSPHRASE"
else
  echo "[i] ssh key "$SSH_KEY_FILE" already exists; skipping"
fi

# Add github ssh config if it hasn't already been added
echo "\n==> Ensuring GitHub SSH config already exists at $SSH_DIR/config"
add_text_if_not_exists "$SSH_DIR/config" "Host github.com\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile $SSH_KEY_FILE" "$ADDED_BY_US_TOKEN"

# Prompt user to add their ssh pub key to their GitHub account, if not already.
cat "$SSH_KEY_FILE.pub" | pbcopy
echo "[i] Your public ssh key has been copied to your clipboard.\n    If you have not already, please add it to your GitHub account at https://github.com/settings/ssh/new.\n    Press 'Enter' to open URL and proceed, or any other key to skip..."
read -n 1 input

if [[ $input == "" ]]; then
  open https://github.com/settings/ssh/new
  echo "[i] Once you have completed this, please press 'Enter' to continue..."
  read
else
  echo "[i] Skipping..."
fi

# Ensure that Homebrew is installed
echo "\n==> Ensuring Homebrew is installed."
if command -v "brew" >/dev/null 2>&1; then
  echo "--> \"brew\" command is available; skipping installation."
else
  echo "--> \"brew\" command unavailable; installing Homebrew (if a password prompt appears, enter your user's password for your machine.)."
  # From https://brew.sh/
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Finalize Homebrew installation (this is what the install.sh script tells us to do)
  echo "--> Running \"Next Steps\" to finalize installation."
  (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  source ~/.zprofile

  # Check that the `brew` command is available and gives us a Homebrew version with the -v arg.
  echo "--> Checking if Homebrew was installed successfully."
  brew -v
  if [ $? -eq 0 ]; then
    echo "[i] Homebrew installed successfully."
  else
    echo "[i] Homebrew not installed successfully; exiting."
    exit 1
  fi
fi

# Create top-level repos dir if it doesn't exist
ensure_dir_exists "$REPOS_DIR" "Top-level repos"

# Install general apps via Homebrew
echo "\n==> Installing general apps via Homebrew."
install_homebrew_cask_packages "${GENERAL_HOMEBREW_CASK_APPS[@]}"
install_homebrew_non_cask_packages "${GENERAL_HOMEBREW_NON_CASK_APPS[@]}"

# Add general aliases to .zprofile
echo "\n==> Ensuring .zprofile has general aliases."
add_text_if_not_exists "$HOME/.zprofile" "$GENERAL_ALIASES" "$ADDED_BY_US_TOKEN"
echo "--> Sourcing .zprofile file."
source "$HOME/.zprofile"

# Set default browser
# First try defaultbrowser Homebrew package method. If that fails, try `open` command method.
echo "\n==> Setting Chrome to default browser."
(echo "--> Installing defaultbrowser Homebrew package." && brew install defaultbrowser && echo "--> Changing default browser." && defaultbrowser chrome) || (echo "--> defaultbrowser tool method failed; trying open command method." && open -a "Google Chrome" --args --make-default-browser)

# ==========================================================
# == Workflow-specific operations                         ==
# ==========================================================

# -----------
# -- ADT   --
# -----------
if [ $WORKFLOW == "adt" ]; then
  # Create ADT repos dir if it doesn't exist
  ensure_dir_exists "$ADT_REPOS_DIR" "ADT repos"

  # Clone ADT repos if they haven't been cloned already
  echo "\n==> [adt workflow] Ensuring ADT repositories are cloned."
  cd "$ADT_REPOS_DIR"
  clone_repos_if_not_exists "${ADT_WORKFLOW_REPOS[@]}"

  # Install ADT apps
  echo "\n==> [adt workflow] Ensuring ADT apps are installed."
  install_homebrew_cask_packages "${ADT_WORKFLOW_HOMEBREW_CASK_APPS[@]}"
fi

echo "\n\n[i] Done! Happy hacking :-)"
