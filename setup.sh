#!/bin/bash
set -e

# Get version from package.json
VERSION=$(grep -m1 '"version"' package.json | cut -d'"' -f4)
LOGFILE="setup.log"
echo "[INFO] Content Automation v$VERSION Setup - Logging all actions to $LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

function log() { echo "[INFO] $1"; }
function warn() { echo "[WARN] $1"; }
function error() { echo "[ERROR] $1" >&2; }

# Cleanup function for failed installations
function cleanup_failed_installation() {
  log "Cleaning up failed installation..."
  rm -rf node_modules
  rm -f ~/.local/bin/content-automation
  rm -f .setup_complete
  log "Cleanup complete. You can re-run setup.sh"
}

# Set trap to run cleanup on failure
trap cleanup_failed_installation ERR

# Retry function for network operations
function retry_command() {
  local max_attempts=3
  local delay=5
  local command="$1"
  local description="$2"

  for ((i = 1; i <= max_attempts; i++)); do
    if eval "$command"; then
      return 0
    else
      if [[ $i -lt $max_attempts ]]; then
        warn "$description failed (attempt $i/$max_attempts). Retrying in ${delay}s..."
        sleep $delay
      else
        error "$description failed after $max_attempts attempts"
        return 1
      fi
    fi
  done
}

# Handle BOTH Intel and Apple Silicon Macs in non-interactive shells
if [ -d "/opt/homebrew/bin" ]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
elif [ -d "/usr/local/bin" ]; then
  export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
fi

echo ""
echo "Content Automation v$VERSION Setup Starting..."
echo ""

# ============================================================================
# STEP 0: Git Pull with Conflict Resolution
# ============================================================================
echo "Step 0/9: Pulling latest changes..."

function git_pull_with_recovery() {
  # Check if we're in a git repo
  if [ ! -d ".git" ]; then
    warn "Not a git repository. Skipping git pull."
    return 0
  fi

  # Fetch latest from origin (graceful failure)
  if ! git fetch origin 2>/dev/null; then
    warn "Could not fetch from origin (network issue?). Continuing with local version."
    return 0
  fi

  # Detect default branch (main or master)
  local default_branch
  if git show-ref --verify --quiet refs/heads/main; then
    default_branch="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    default_branch="master"
  else
    default_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
  fi

  # Abort any in-progress rebase or merge
  git rebase --abort 2>/dev/null || true
  git merge --abort 2>/dev/null || true

  # Try git pull --rebase first
  if git pull --rebase origin "$default_branch" 2>/dev/null; then
    log "Git pull --rebase successful"
    return 0
  fi

  # Fall back to regular merge
  warn "Rebase failed, trying merge..."
  if git pull origin "$default_branch" 2>/dev/null; then
    log "Git pull (merge) successful"
    return 0
  fi

  # Final fallback: hard reset (preserves .env and node_modules)
  warn "Merge failed. Performing hard reset to origin/$default_branch..."
  warn "Preserving: .env, node_modules/"

  git reset --hard "origin/$default_branch"
  git clean -fd -e .env -e node_modules

  log "Hard reset complete. Local changes have been discarded."
  return 0
}

git_pull_with_recovery

# ============================================================================
# STEP 1: System Dependencies (macOS)
# ============================================================================
echo ""
echo "Step 1/9: Installing system dependencies..."

function install_homebrew() {
  if ! command -v brew &> /dev/null; then
    log "Installing Homebrew..."
    retry_command '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' "Homebrew installation"
    eval "$($(brew --prefix)/bin/brew shellenv)"
    log "Homebrew installed successfully"
  else
    log "Homebrew already installed"
  fi
}

function install_required_tools() {
  local tools=("git" "gh" "node")

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      log "Installing $tool via Homebrew..."
      retry_command "brew install $tool" "$tool installation"
      log "$tool installed successfully"
    else
      log "$tool already installed"
    fi
  done
}

function check_optional_tools() {
  # ImageMagick for AVIF->JPEG conversion
  if command -v convert &> /dev/null; then
    log "ImageMagick found (image conversion available)"
  else
    warn "ImageMagick not installed. AVIF->JPEG conversion will not be available."
    warn "Install with: brew install imagemagick"
  fi

  # Docker for Redis job queue
  if command -v docker &> /dev/null; then
    log "Docker found"
  else
    warn "Docker not installed. Redis job queue will not be available."
    warn "Install from: https://www.docker.com/products/docker-desktop/"
  fi
}

function setup_github_auth() {
  log "Checking GitHub CLI authentication..."

  if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is required but not installed."
    error "Install with: brew install gh"
    return 1
  fi

  if ! gh auth status &> /dev/null; then
    echo ""
    echo "=================================================="
    echo "  GitHub CLI Authentication Required"
    echo "=================================================="
    echo ""
    echo "GitHub CLI must be authenticated to fetch credentials."
    echo "This will open a browser for GitHub login."
    echo ""

    if [ -t 0 ] && [ -t 1 ]; then
      gh auth login -p https -w
      if gh auth status &> /dev/null; then
        log "GitHub CLI authenticated successfully"
      else
        warn "GitHub CLI authentication failed. Credential fetching may not work."
      fi
    else
      warn "Non-interactive mode. Please run 'gh auth login' manually."
    fi
  else
    log "GitHub CLI already authenticated"
  fi
}

# Only run Homebrew installation on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  install_homebrew
  install_required_tools
  check_optional_tools
  setup_github_auth
else
  warn "Non-macOS system detected. Please ensure git, gh, and node 20.9+ are installed manually."
  setup_github_auth
fi

# ============================================================================
# STEP 2: Node.js Version Check
# ============================================================================
echo ""
echo "Step 2/9: Checking Node.js version..."

function install_nvm_if_needed() {
  if [ ! -s "$HOME/.nvm/nvm.sh" ] && ! command -v nvm &> /dev/null; then
    log "Installing NVM (Node Version Manager)..."
    if command -v brew &> /dev/null; then
      retry_command "brew install nvm" "NVM installation via Homebrew"
      mkdir -p "$HOME/.nvm"
      log "NVM installed via Homebrew"
    else
      retry_command 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash' "NVM installation via curl"
      log "NVM installed via curl"
    fi
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  fi
}

function install_node_via_nvm() {
  install_nvm_if_needed

  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    log "NVM detected. Installing Node.js 20..."
    source "$HOME/.nvm/nvm.sh"
    retry_command "nvm install 20" "Node.js 20 installation via nvm"
    retry_command "nvm use 20" "Switching to Node.js 20"
    retry_command "nvm alias default 20" "Setting Node.js 20 as default"
    return 0
  elif command -v nvm &> /dev/null; then
    log "NVM command available. Installing Node.js 20..."
    retry_command "nvm install 20" "Node.js 20 installation via nvm"
    retry_command "nvm use 20" "Switching to Node.js 20"
    retry_command "nvm alias default 20" "Setting Node.js 20 as default"
    return 0
  fi
  return 1
}

# Returns 0 if node version string (e.g. 20.9.0) meets Next.js requirement >=20.9.0
function node_version_ok() {
  local v="$1"
  local major minor
  major=$(echo "$v" | cut -d. -f1)
  minor=$(echo "$v" | cut -d. -f2)
  [ -z "$major" ] && return 1
  [ "$major" -gt 20 ] 2>/dev/null && return 0
  [ "$major" -eq 20 ] 2>/dev/null && [ -n "$minor" ] && [ "$minor" -ge 9 ] 2>/dev/null && return 0
  return 1
}

function check_node_version() {
  if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d. -f1)
    log "Found Node.js version $NODE_VERSION"
  else
    log "Node.js not found, will attempt installation..."
    NODE_VERSION="0.0.0"
    MAJOR_VERSION=0
  fi

  if ! node_version_ok "$NODE_VERSION"; then
    if [ "$MAJOR_VERSION" -gt 0 ]; then
      warn "Node.js version $NODE_VERSION detected. This project requires Node.js >=20.9.0 (Next.js)."
    fi

    # Try different installation methods in order of preference
    if brew list node &> /dev/null; then
      log "Upgrading Node.js via Homebrew..."
      retry_command "brew upgrade node" "Node.js upgrade"
    elif install_node_via_nvm; then
      log "Node.js 20 installed via nvm"
    elif command -v brew &> /dev/null; then
      log "Installing Node.js 20 via Homebrew..."
      retry_command "brew install node" "Node.js installation"
    else
      error "Cannot install Node.js automatically. Please install manually:"
      error "  1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      error "  2. Install Node.js: brew install node"
      error "  3. Or install nvm and run: nvm install 20 && nvm use 20"
      error "  4. Or download from https://nodejs.org/"
      return 1
    fi

    # Verify installation worked
    if command -v node &> /dev/null; then
      NEW_NODE_VERSION=$(node --version | sed 's/v//')
      if ! node_version_ok "$NEW_NODE_VERSION"; then
        error "Node.js installation/upgrade failed. Version is still $NEW_NODE_VERSION (need >=20.9.0)"
        return 1
      fi
      log "Node.js version $NEW_NODE_VERSION is now available"
    else
      error "Node.js installation failed - command not found after installation"
      return 1
    fi
  else
    log "Node.js version $NODE_VERSION is compatible (>=20.9.0 required for Next.js)"
  fi
}

check_node_version

# ============================================================================
# STEP 3: PATH Configuration
# ============================================================================
echo ""
echo "Step 3/9: Setting up PATH and shell configuration..."

function setup_local_bin_path() {
  LOCAL_BIN_DIR="$HOME/.local/bin"
  ZSHRC_FILE="$HOME/.zshrc"
  ZPROFILE_FILE="$HOME/.zprofile"

  # Create the directory if it doesn't exist
  mkdir -p "$LOCAL_BIN_DIR"

  # Add to .zshrc if not already present
  if ! grep -q "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$ZSHRC_FILE" 2>/dev/null; then
    log "Adding ~/.local/bin to PATH in $ZSHRC_FILE"
    echo -e "\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$ZSHRC_FILE"
    export PATH="$LOCAL_BIN_DIR:$PATH"
    log "~/.local/bin added to PATH"
  else
    log "~/.local/bin already in PATH"
  fi

  # Also add to .zprofile for login shells
  if ! grep -q "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$ZPROFILE_FILE" 2>/dev/null; then
    echo -e "\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$ZPROFILE_FILE"
  fi

  # Add NVM configuration if not already present
  if ! grep -q "##### NVM CONFIGURATION #####" "$ZSHRC_FILE" 2>/dev/null; then
    log "Adding NVM configuration to $ZSHRC_FILE"
    cat >> "$ZSHRC_FILE" << 'ZSHRC_EOF'

##### NVM CONFIGURATION #####
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Auto-switch Node versions based on .nvmrc file
autoload -U add-zsh-hook
load-nvmrc() {
  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc
ZSHRC_EOF
    log "NVM configuration added"
  else
    log "NVM configuration already present"
  fi

  # Add Homebrew paths for M1/M2/M3 Macs if not already present
  if ! grep -q "##### HOMEBREW CONFIGURATION #####" "$ZSHRC_FILE" 2>/dev/null; then
    log "Adding Homebrew configuration to $ZSHRC_FILE"
    cat >> "$ZSHRC_FILE" << 'ZSHRC_EOF'

##### HOMEBREW CONFIGURATION #####
# Add Homebrew to PATH (supports both Intel and Apple Silicon Macs)
if [[ -d "/opt/homebrew" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    export PATH="/opt/homebrew/sbin:$PATH"
elif [[ -d "/usr/local/Homebrew" ]]; then
    export PATH="/usr/local/bin:$PATH"
    export PATH="/usr/local/sbin:$PATH"
fi
ZSHRC_EOF
    log "Homebrew configuration added"
  else
    log "Homebrew configuration already present"
  fi

  # Add content-automation aliases if not already present
  if ! grep -q "##### CONTENT-AUTOMATION ALIASES #####" "$ZSHRC_FILE" 2>/dev/null; then
    log "Adding content-automation aliases to $ZSHRC_FILE"
    cat >> "$ZSHRC_FILE" << 'ZSHRC_EOF'

##### CONTENT-AUTOMATION ALIASES #####
# Git shortcuts
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline -10"

# Development shortcuts
alias ll="ls -la"
alias la="ls -la"
alias ..="cd .."
alias ...="cd ../.."
ZSHRC_EOF
    log "Content-automation aliases added"
  else
    log "Content-automation aliases already present"
  fi
}

setup_local_bin_path

# ============================================================================
# STEP 4: Install Node Dependencies
# ============================================================================
echo ""
echo "Step 4/9: Installing Node dependencies..."

function install_node_dependencies() {
  log "Running npm install (triggers postinstall: prisma generate + playwright install)..."

  # Ensure npm/node paths are available
  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

  # Try multiple approaches to handle certificate issues
  if npm install 2>/dev/null; then
    log "npm install successful"
  elif npm install --strict-ssl=false 2>/dev/null; then
    log "npm install successful with relaxed SSL"
  elif npm install --registry http://registry.npmjs.org/ 2>/dev/null; then
    log "npm install successful using HTTP registry"
  elif npm config set cafile "" && npm install 2>/dev/null; then
    log "npm install successful after clearing certificate config"
  else
    error "npm install failed. Please check your network connection and try again."
    return 1
  fi

  # Verify Prisma client was generated
  if [ -d "node_modules/.prisma/client" ]; then
    log "Prisma client generated successfully"
  else
    warn "Prisma client not found. Running prisma generate..."
    npx prisma generate
  fi

  # Verify Playwright browsers
  if npx playwright --version &> /dev/null; then
    log "Playwright installed successfully"
  else
    warn "Playwright verification failed. Running playwright install..."
    npx playwright install
  fi
}

retry_command "install_node_dependencies" "npm dependencies installation"

# ============================================================================
# STEP 5: Environment Configuration
# ============================================================================
echo ""
echo "Step 5/9: Setting up environment configuration..."

function setup_environment_config() {
  if [ ! -f ".env" ]; then
    log "Creating .env from template"
    cp .env.example .env
    log ".env file created from template"
  else
    log ".env file already exists"
  fi
}

setup_environment_config

# --- Fetch Supabase Credentials via GitHub Actions artifact ---
function fetch_supabase_credentials_from_github_actions() {
  local workflow_file="fetch-supabase-credentials.yml"
  local artifact_name="supabase-credentials"
  local download_dir="/tmp/content-automation-supabase"
  SUPABASE_FETCH_OK=0

  log "Fetching Supabase credentials via GitHub Actions..."

  if ! command -v gh &> /dev/null; then
    warn "GitHub CLI not found. Cannot fetch credentials automatically."
    return 0
  fi

  # Check if user is authenticated
  if ! gh auth status &> /dev/null; then
    warn "GitHub CLI not authenticated. Please run 'gh auth login' first."
    return 0
  fi

  # Check if workflow exists
  if ! gh workflow list --json path -q '.[].path' 2>/dev/null | grep -q "$workflow_file"; then
    warn "GitHub Actions workflow not found: $workflow_file"
    return 0
  fi

  local start_time
  start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Trigger workflow run
  if ! gh workflow run "$workflow_file" &> /dev/null; then
    warn "Failed to trigger GitHub Actions workflow: $workflow_file"
    warn "Attempting to refresh GitHub auth scopes (workflow, repo) and retry..."
    gh auth refresh -s workflow,repo &> /dev/null || true
    if ! gh workflow run "$workflow_file" &> /dev/null; then
      warn "Retry failed. Attempting to use latest successful workflow run artifact..."

      # Fall back to latest successful run artifact
      local latest_success_id
      latest_success_id=$(gh run list --workflow "$workflow_file" --limit 10 --json databaseId,conclusion -q 'map(select(.conclusion=="success")) | .[0].databaseId' 2>/dev/null)
      if [ -z "$latest_success_id" ]; then
        warn "No successful workflow runs found"
        return 0
      fi
      run_id="$latest_success_id"

      # Download from cached run
      rm -rf "$download_dir"
      mkdir -p "$download_dir"
      if ! gh run download "$run_id" -n "$artifact_name" -D "$download_dir" &> /dev/null; then
        warn "Failed to download artifact from latest successful run"
        return 0
      fi

      # Process downloaded credentials
      process_downloaded_credentials
      return 0
    fi
  fi

  # Wait for latest run to complete (polling with timeout)
  local run_id=""
  for _ in {1..30}; do
    run_id=$(gh run list --workflow "$workflow_file" --limit 5 --json databaseId,createdAt -q 'map(select(.createdAt > "'"$start_time"'")) | .[0].databaseId' 2>/dev/null)
    if [ -n "$run_id" ]; then
      run_status=$(gh run view "$run_id" --json status -q '.status' 2>/dev/null)
      run_conclusion=$(gh run view "$run_id" --json conclusion -q '.conclusion' 2>/dev/null)
      if [ "$run_status" = "completed" ]; then
        if [ "$run_conclusion" != "success" ]; then
          warn "GitHub Actions run failed (conclusion: $run_conclusion)"
          return 0
        fi
        break
      fi
    fi
    sleep 2
  done

  if [ -z "$run_id" ]; then
    warn "Could not find a completed GitHub Actions run"
    return 0
  fi

  rm -rf "$download_dir"
  mkdir -p "$download_dir"

  if ! gh run download "$run_id" -n "$artifact_name" -D "$download_dir" &> /dev/null; then
    warn "Failed to download artifact: $artifact_name"
    return 0
  fi

  process_downloaded_credentials
}

function process_downloaded_credentials() {
  local anon_key_file="/tmp/content-automation-supabase/supabase_anon_key.txt"
  local db_password_file="/tmp/content-automation-supabase/db_password.txt"

  # Process NEXT_PUBLIC_SUPABASE_ANON_KEY
  if [ -f "$anon_key_file" ]; then
    local anon_key
    anon_key="$(cat "$anon_key_file" | tr -d '\r\n')"
    if [ -n "$anon_key" ]; then
      log "NEXT_PUBLIC_SUPABASE_ANON_KEY fetched from GitHub Actions"
      sed -i.bak "/^NEXT_PUBLIC_SUPABASE_ANON_KEY=/d" .env
      rm -f .env.bak
      echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=$anon_key" >> .env
      export NEXT_PUBLIC_SUPABASE_ANON_KEY="$anon_key"
    fi
  fi

  # Process DB_PASSWORD
  if [ -f "$db_password_file" ]; then
    local db_password
    db_password="$(cat "$db_password_file" | tr -d '\r\n')"
    if [ -n "$db_password" ]; then
      log "DB_PASSWORD fetched from GitHub Actions"
      sed -i.bak "/^DB_PASSWORD=/d" .env
      rm -f .env.bak
      echo "DB_PASSWORD=$db_password" >> .env
      export DB_PASSWORD="$db_password"

      # Also update DATABASE_URL with the password
      update_database_url_with_password "$db_password"
    fi
  fi

  SUPABASE_FETCH_OK=1
}

function update_database_url_with_password() {
  local password="$1"
  local base_url="postgresql://postgres.ggrucwtukdpbvujxffbc"
  local host="@aws-1-us-east-2.pooler.supabase.com:5432/postgres"
  local full_url="${base_url}:${password}${host}"

  sed -i.bak "/^DATABASE_URL=/d" .env
  rm -f .env.bak
  echo "DATABASE_URL=\"$full_url\"" >> .env
  export DATABASE_URL="$full_url"
  log "DATABASE_URL updated with password"
}

function validate_supabase_credentials() {
  local PLACEHOLDER_ANON_KEY="{NEXT_PUBLIC_SUPABASE_ANON_KEY}"
  local PLACEHOLDER_DB_PASSWORD="{DB_PASSWORD}"
  local PLACEHOLDER_PROJECT_PW="[PROJECT-PW]"

  # Try reading from .env
  if [ -f ".env" ]; then
    ENV_ANON_KEY=$(grep -E "^NEXT_PUBLIC_SUPABASE_ANON_KEY=" .env | tail -n 1 | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    ENV_DB_PASSWORD=$(grep -E "^DB_PASSWORD=" .env | tail -n 1 | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  fi

  # Check if credentials are placeholders or missing
  local needs_anon_key=0
  local needs_db_password=0

  if [ -z "$ENV_ANON_KEY" ] || [ "$ENV_ANON_KEY" = "$PLACEHOLDER_ANON_KEY" ]; then
    needs_anon_key=1
  fi

  if [ -z "$ENV_DB_PASSWORD" ] || [ "$ENV_DB_PASSWORD" = "$PLACEHOLDER_DB_PASSWORD" ] || [ "$ENV_DB_PASSWORD" = "$PLACEHOLDER_PROJECT_PW" ]; then
    needs_db_password=1
  fi

  if [ $needs_anon_key -eq 1 ] || [ $needs_db_password -eq 1 ]; then
    echo ""
    echo "=================================================="
    echo "  Supabase Credentials Required"
    echo "=================================================="
    echo ""
    echo "The following credentials could not be fetched automatically:"
    [ $needs_anon_key -eq 1 ] && echo "  - NEXT_PUBLIC_SUPABASE_ANON_KEY"
    [ $needs_db_password -eq 1 ] && echo "  - DB_PASSWORD"
    echo ""
    echo "Contact your admin for credentials, or enter them manually."
    echo ""

    if [ -t 0 ] && [ -t 1 ]; then
      if [ $needs_anon_key -eq 1 ]; then
        read -p "Enter NEXT_PUBLIC_SUPABASE_ANON_KEY (or press Enter to skip): " USER_ANON_KEY
        if [ -n "$USER_ANON_KEY" ]; then
          sed -i.bak "/^NEXT_PUBLIC_SUPABASE_ANON_KEY=/d" .env && rm -f .env.bak
          echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=$USER_ANON_KEY" >> .env
          log "NEXT_PUBLIC_SUPABASE_ANON_KEY stored in .env"
        fi
      fi

      if [ $needs_db_password -eq 1 ]; then
        read -s -p "Enter DB_PASSWORD (or press Enter to skip): " USER_DB_PASSWORD
        echo ""
        if [ -n "$USER_DB_PASSWORD" ]; then
          sed -i.bak "/^DB_PASSWORD=/d" .env && rm -f .env.bak
          echo "DB_PASSWORD=$USER_DB_PASSWORD" >> .env
          update_database_url_with_password "$USER_DB_PASSWORD"
          log "DB_PASSWORD stored in .env"
        fi
      fi
    else
      warn "Non-interactive mode. Please manually update .env with credentials."
    fi
  else
    log "Supabase credentials detected"
  fi

  return 0
}

# Try to fetch credentials from GitHub Actions
fetch_supabase_credentials_from_github_actions

# Validate and prompt for missing credentials
validate_supabase_credentials

# ============================================================================
# STEP 6: Database Connection Test
# ============================================================================
echo ""
echo "Step 6/9: Testing database connection..."

function test_database_connection() {
  log "Testing Prisma database connection..."

  # Check if DATABASE_URL has placeholder
  if grep -q "\[PROJECT-PW\]" .env 2>/dev/null || grep -q "{DB_PASSWORD}" .env 2>/dev/null; then
    warn "DATABASE_URL contains placeholder. Database connection test skipped."
    return 0
  fi

  if npx prisma db pull --print &> /dev/null; then
    log "Database connection successful"
  else
    warn "Database connection failed. Please check your DATABASE_URL in .env"
    warn "You can run 'npx prisma db pull' to test the connection manually."
  fi
}

test_database_connection

# ============================================================================
# STEP 7: Git Hooks Setup
# ============================================================================
echo ""
echo "Step 7/9: Setting up Git hooks..."

function setup_git_hooks() {
  log "Installing Husky git hooks..."

  if npm run prepare 2>/dev/null; then
    log "Husky git hooks installed"
  else
    warn "Husky installation failed. Git hooks may not work."
  fi

  # Verify .husky directory exists
  if [ -d ".husky" ]; then
    log ".husky directory exists"
  else
    warn ".husky directory not found. Git hooks may not be configured."
  fi
}

setup_git_hooks

# ============================================================================
# STEP 8: Validation
# ============================================================================
echo ""
echo "Step 8/9: Validating installation..."

function validate_installation() {
  local validation_passed=1

  # Check node_modules/.prisma/client exists
  if [ -d "node_modules/.prisma/client" ]; then
    log "Prisma client validated"
  else
    warn "Prisma client not found"
    validation_passed=0
  fi

  # Check Playwright browsers
  if npx playwright --version &> /dev/null; then
    log "Playwright validated"
  else
    warn "Playwright not properly installed"
    validation_passed=0
  fi

  # Test Next.js lint (quick validation)
  if npm run lint:web &> /dev/null; then
    log "Next.js lint passed"
  else
    warn "Next.js lint failed (may need ESLint configuration)"
  fi

  if [ $validation_passed -eq 1 ]; then
    log "All validations passed"
  else
    warn "Some validations failed. The setup may still work."
  fi
}

validate_installation

# ============================================================================
# STEP 9: Create Global Wrapper (Optional)
# ============================================================================
echo ""
echo "Step 9/9: Creating global wrapper script..."

function create_global_wrapper() {
  PROJECT_ROOT=$(pwd)
  LOCAL_BIN_DIR="$HOME/.local/bin"
  WRAPPER_PATH="$LOCAL_BIN_DIR/content-automation"

  log "Creating wrapper script at $WRAPPER_PATH"

  mkdir -p "$LOCAL_BIN_DIR"

  cat > "$WRAPPER_PATH" << EOF
#!/bin/bash
# Enhanced wrapper script for content-automation v$VERSION
# Auto-generated by setup.sh with validation

PROJECT_ROOT="$PROJECT_ROOT"

# Check if project root exists
if [ ! -d "\$PROJECT_ROOT" ]; then
    echo "Content-automation project directory not found at \$PROJECT_ROOT" >&2
    echo "Please clone the repository or run setup.sh from the correct directory" >&2
    exit 1
fi

# Check if node_modules exists
if [ ! -d "\$PROJECT_ROOT/node_modules" ]; then
    echo "node_modules not found. Running setup.sh to install dependencies..." >&2
    cd "\$PROJECT_ROOT" && bash setup.sh
fi

# Check if Prisma client exists
if [ ! -d "\$PROJECT_ROOT/node_modules/.prisma/client" ]; then
    echo "Prisma client not found. Running setup.sh to regenerate..." >&2
    cd "\$PROJECT_ROOT" && bash setup.sh
fi

# Change to project directory
cd "\$PROJECT_ROOT" || {
    echo "Failed to change to project directory \$PROJECT_ROOT" >&2
    exit 1
}

# Default command is dev:web
COMMAND="\${1:-dev:web}"

case "\$COMMAND" in
  dev|dev:web)
    npm run dev:web
    ;;
  build)
    npm run build
    ;;
  start|start:web)
    npm run start:web
    ;;
  scrape)
    npm run scrape
    ;;
  process)
    npm run process
    ;;
  *)
    npm run "\$COMMAND"
    ;;
esac
EOF

  # Make the wrapper executable
  chmod +x "$WRAPPER_PATH"
  log "Global 'content-automation' command created successfully"
}

create_global_wrapper

# ============================================================================
# COMPLETION
# ============================================================================
echo ""
echo "=================================================="
echo "  Content Automation v$VERSION Setup Complete!"
echo "=================================================="
echo ""
echo "All steps completed successfully!"
echo ""

touch .setup_complete
log ".setup_complete marker file created."

# Check if credentials are still missing - if so, don't start server
if grep -q "\[PROJECT-PW\]" .env 2>/dev/null || grep -q "{DB_PASSWORD}" .env 2>/dev/null; then
  echo "WARNING: Database credentials still contain placeholders."
  echo "Please update .env with valid Supabase credentials, then run:"
  echo "   npm run dev:web"
  echo ""
  echo "Documentation: README.md"
  exit 0
fi

# Start the development server and open browser
echo "Starting development server..."
echo ""

# Start npm run dev:web in background
npm run dev:web &
DEV_PID=$!

# Wait for server to be ready (check for port 3000)
echo "Waiting for server to start..."
for i in {1..30}; do
  if curl -s http://localhost:3000 > /dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Open browser to signup page
if [[ "$OSTYPE" == "darwin"* ]]; then
  open "http://localhost:3000/auth/signup"
elif command -v xdg-open &> /dev/null; then
  xdg-open "http://localhost:3000/auth/signup"
fi

echo ""
echo "Browser opened to http://localhost:3000/auth/signup"
echo "Development server running (PID: $DEV_PID)"
echo ""
echo "Press Ctrl+C to stop the server."
echo ""

# Wait for the dev server process
wait $DEV_PID
