#!/usr/bin/env bash

VERSION="1.0.3"

# ==========================================================
# == Args & Constants                                     ==
# ==========================================================

# -- Args
# Provide friendly name to 1st arg (<workflow>)
WORKFLOW=$1

# -- Constants
# Root dir of all cloned repositories
REPOS_DIR="$HOME/workspace"
# Dir to SSH config
SSH_DIR="$HOME/.ssh"
# Path to SSH key file (for id_ed25519)
SSH_KEY_FILE="$SSH_DIR/id_ed25519"
# Path (no trailing '/') to our GitHub SSH clone path
GITHUB_REPOS_SSH_PREFIX="git@github.com:VorTECHsa"
# Token that is used as a prefix for any content added to any files
# such as .zprofile, such that we know if we should add content to them.
# This keeps the script idempotent (re-runnable without bad affects).
ADDED_BY_US_TOKEN="# -- Added by vcli"
# URL to the repository of this tool
REPO_URL="https://github.com/VorTECHsa/adt-vtx-setup-cli"
# URLs to various GitHub pages used to enter in or generate keys and such
GITHUB_ADD_SSH_KEY_URL="https://github.com/settings/ssh/new"
GITHUB_CREATE_PAT_URL="https://github.com/settings/tokens"

# ==========================================================
# == General configuration (for all workflows)            ==
# ==========================================================

# General Homebrew apps to install
GENERAL_HOMEBREW_CASK_APPS=("visual-studio-code" "insomnia" "cyberduck" "google-chrome" "aws-vpn-client")
GENERAL_HOMEBREW_NON_CASK_APPS=("awscli" "sops" "aws-iam-authenticator" "kubectl")

# General helpful aliases
GENERAL_ALIASES_ZSHRC="
# Misc. Aliases
alias cls='clear'

# Git Aliases
alias gs='git status'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gc='git commit'
alias gcm='git commit -m'
alias gm='git merge'
alias gp='git push'
alias gf='git fetch'
alias gp='git push'
alias gl='git pull'
"

# Provides the `asp` command for all terminals.
ASP_COMMAND_ZSHRC='
# Lists available aws profiles from ~/.aws/config
function aws_profiles() {
  aws --no-cli-pager configure list-profiles 2> /dev/null && return
  [[ -r "${AWS_CONFIG_FILE:-$HOME/.aws/config}" ]] || return 1
  grep --color=never -Eo '\''\[.*\]'\'' "${AWS_CONFIG_FILE:-$HOME/.aws/config}" | sed -E '\''s/^[[:space:]]*\[(profile)?[[:space:]]*([^[:space:]]+)\][[:space:]]*$/\2/g'\''
}

# AWS profile selection
function asp() {
  if [[ -z "$1" ]]; then
    unset AWS_DEFAULT_PROFILE AWS_PROFILE AWS_EB_PROFILE AWS_PROFILE_REGION
    echo AWS profile cleared.
    return
  fi

  local -a available_profiles
  available_profiles=($(aws_profiles))
  if [[ -z "${available_profiles[(r)$1]}" ]]; then
    echo "${fg[red]}Profile '\''$1'\'' not found in '\''${AWS_CONFIG_FILE:-$HOME/.aws/config}'\''" >&2
    echo "Available profiles: ${(j:, :)available_profiles:-no profiles found}${reset_color}" >&2
    return 1
  fi

  export AWS_DEFAULT_PROFILE=$1
  export AWS_PROFILE=$1
  export AWS_EB_PROFILE=$1

  export AWS_PROFILE_REGION=$(aws configure get region)

  if [[ "$2" == "login" ]]; then
    aws sso login
  fi
}
'

KUBE_TOKEN_GEN_ZSHRC='
# Generate access token to your clipboard for authenticating into our Kubernetes dashboards
function kubeToken() {
  kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '\''{print $1}'\'')  | awk '\''$1=="token:"{print $2}'\'' | pbcopy
}
'

# ==========================================================
# == Workflow-specific configuration                      ==
# ==========================================================

# The supported workflows. Add to this when more workflows are desired.
SUPPORTED_WORKFLOWS=("adt")

# --------------------------------------
# -- ADT workflow configuration       --
# --------------------------------------

# The directory that repositories are cloned within
ADT_REPOS_DIR="$REPOS_DIR/adt"
# The repositories that are cloned
ADT_WORKFLOW_REPOS=("web" "api" "app-core" "adt-publish-workers")
# The apps that are installed (via Homebrew)
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

# Returns 1 if `file` exists and contains the given `token`.
does_file_with_string_exist() {
  local file="$1"
  local token="$2"

  echo "--> Checking if $file already exists"
  if [ ! -e "$file" ]; then
    return 0
  fi

  echo "--> $file exists; checking if it already contains token."
  if ! grep -qF "$token" "$file"; then
    return 0
  else
    return 1
  fi
}

# Ensures that the given `file` exists and contains the given `text`, using the given `token` as a test.
add_text_if_not_exists() {
  local file="$1"
  local text="$2"
  local token="$3"

  local textToAdd="\n$token$text"

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
    echo "[i] $repo repository dir already exists; skipping."
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
    echo "[i] App '$package' is already installed; skipping."
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
    echo "[i] App '$package' is already installed; skipping."
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

  <workflow>                Optional workflow to enable. Possible values: $supported_workflows_str

  sh setup.sh --help        show this usage help text
  sh setup.sh --version     show version"

# Print version screen and exit if first param is "version"-like
if [ "$1" == "--version" ] || [ "$1" == "-v" ] || [ "$1" == "version" ] || [ "$1" == "v" ]; then
  echo "$VERSION"
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
  echo "------------------------------------------------------------"
  echo "[!] <workflow> argument has not been supplied."
  echo "    This means a general-only setup will be performed."
  echo "    Run with '--help' for more information."
  echo
  echo "    If this is okay, press 'Enter' to proceed. Else, any other character to abort."
  echo "------------------------------------------------------------"
  read -n 1 input
  if [[ $input != "" ]]; then
    echo "Exiting."
    exit 0
  else
    echo "[i] Proceeding."
  fi
fi

# Print splash (*after* version arg handling, arg validation, etc.)
echo
echo "----------------------------------------"
echo "--        Vortexa Setup Utility       --"
echo "----------------------------------------"
echo

# Print help screen and exit if first param is "help"-like
if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "help" ] || [ "$1" == "h" ]; then
  echo "$USAGE"
  echo
  echo "Repository: $REPO_URL"
  echo
  exit 0
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
echo "------------------------------------------------------------"
echo "[i] Your $SSH_KEY_FILE.pub public SSH key has"
echo "    been copied to your clipboard. If you have not already,"
echo "    add it to your GitHub account at $GITHUB_ADD_SSH_KEY_URL."
echo
echo "    Press 'Enter' to open URL and proceed, or any other key to skip..."
echo "------------------------------------------------------------"
read -n 1 input

if [[ $input == "" ]]; then
  open "$GITHUB_ADD_SSH_KEY_URL"
  echo "[i] Once you have completed the above, press 'Enter' to continue..."
  echo "------------------------------------------------------------"
  read
else
  echo "[i] Skipping..."
fi

# ==========================================================
# == .npmrc file setup                                    ==
# ==========================================================

echo "\n==> Ensuring ~/.npmrc file is configured."

does_file_with_string_exist "$HOME/.npmrc" "$ADDED_BY_US_TOKEN"
if [ $? -eq 0 ]; then
  echo "[i] ~/.npmrc file does not contain content added by this tool."
  echo "------------------------------------------------------------"
  echo "[i] You need to create a new GitHub Personal Access Token (classic)."
  echo "    You need to go to the URL: $GITHUB_CREATE_PAT_URL"
  echo "      * Click the 'Generate new token' button"
  echo "      * Give a meaningful name, e.g. 'vortexa-npmrc'"
  echo "      * Set permissions for all repo and 'write:packages' and 'read:packages'"
  echo "      * Click the 'Generate token' button"
  echo "      * Copy the token to your clipboard to paste into here later."
  echo
  echo "    Press 'Enter' to open this URL and proceed, or any other key to skip this step..."
  echo "------------------------------------------------------------"

  read -n 1 input
  if [[ $input == "" ]]; then
    open "$GITHUB_CREATE_PAT_URL"
    echo "GitHub Personal Access Token (classic):" 
    read -s GITHUB_PAT
  else
    echo "[i] Skipping..."
  fi

  echo "------------------------------------------------------------"
  echo "[i] You need to get a Font Awesome NPM auth token."
  echo "    If you have not got one already on-hand, ask your pod lead"
  echo "    or team for the key."
  echo
  echo "    Press 'Enter' to provide this key, or any other key to skip this step..."
  echo "------------------------------------------------------------"

  read -n 1 input
  if [[ $input == "" ]]; then
    echo "Font Awesome NPM auth token:" 
    read -s FONT_AWESOME_AUTH_TOKEN
  else
    echo "[i] Skipping..."
  fi

  if [[ -z "$GITHUB_PAT" && -z "$FONT_AWESOME_AUTH_TOKEN" ]]; then
    echo "[!] Both npmrc steps skipped; not creating .npmrc file."
  else
    NPMRC_TEXT="
@vortechsa:registry=https://npm.pkg.github.com/VorTECHsa
//npm.pkg.github.com/:_authToken=$GITHUB_PAT

@fortawesome:registry=https://npm.fontawesome.com/
//npm.fontawesome.com/:_authToken=$FONT_AWESOME_AUTH_TOKEN
user=0
unsafe-perm=true"

    add_text_if_not_exists "$HOME/.npmrc" "$NPMRC_TEXT" "$ADDED_BY_US_TOKEN"
  fi
else
  echo "[i] ~/.npmrc file already contains content added by this tool; skipping."
fi

# ==========================================================
# == Homebrew installation                                ==
# ==========================================================

echo "\n==> Ensuring Homebrew is installed."
if command -v "brew" >/dev/null 2>&1; then
  echo "[i] \"brew\" command is available; skipping installation."
else
  echo "--> \"brew\" command unavailable; installing Homebrew (if a password prompt appears, enter your user's password for your machine.)."
  # From https://brew.sh/
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Finalize Homebrew installation (this is what the install.sh script tells us to do)
  echo "--> Running \"Next Steps\" to finalize installation."
  (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  source "$HOME/.zprofile"

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

# ==========================================================

# Ensure top-level repos dir exists
ensure_dir_exists "$REPOS_DIR" "Top-level repos"

echo "\n==> Ensuring Rosetta is installed. This may prompt you for your machine user's password."
echo "------------------------------------------------------------"
# Ensure rosetta is installed (currently required by aws-vpn-client app)
sudo softwareupdate --install-rosetta

# Ensure general apps are installed (via Homebrew)
echo "\n==> Installing general apps via Homebrew."
install_homebrew_cask_packages "${GENERAL_HOMEBREW_CASK_APPS[@]}"
install_homebrew_non_cask_packages "${GENERAL_HOMEBREW_NON_CASK_APPS[@]}"

# Ensure general aliases and other .zshrc content is added
echo "\n==> Ensuring .zshrc has general aliases and asp command."
add_text_if_not_exists "$HOME/.zshrc" "$GENERAL_ALIASES_ZSHRC\n\n$ASP_COMMAND_ZSHRC\n\n$KUBE_TOKEN_GEN_ZSHRC" "$ADDED_BY_US_TOKEN"
echo "--> Sourcing .zshrc file."
source "$HOME/.zshrc"

# Ensure NVM is installed (their install script is idempotent out-of-the-box)
echo "\n==> Ensuring Node Version Manager (nvm) is installed."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
echo "--> Sourcing .zshrc file."
source "$HOME/.zshrc"
# Check that the `nvm` command is available and gives us a Homebrew version with the -v arg.
echo "--> Checking if NVM was installed successfully."
nvm -v
if [ $? -eq 0 ]; then
  echo "[i] NVM installed successfully."
else
  echo "[i] NVM not installed successfully; exiting."
  exit 1
fi

# Set default browser to Google Chrome
echo "\n==> Setting Chrome to default browser."
# First try defaultbrowser Homebrew package. If that fails, try `open` command instead.
(install_homebrew_non_cask_package "defaultbrowser" && echo "--> Changing default browser." && defaultbrowser chrome) || (echo "--> defaultbrowser tool failed; trying open command method instead." && open -a "Google Chrome" --args --make-default-browser)

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

echo ""
echo "[i] Note: some commands may only be available after you restart your terminal."
echo ""
echo "----------------------------------------"
echo "--       Done! Happy hacking :-)      --"
echo "----------------------------------------"
echo ""
