#!/bin/bash

# Enhanced error handling
set -e
set -o pipefail

# Configuration
LOG_FILE="setup.log"
ERROR_LOG="setup_errors.log"
BACKUP_DIR="$HOME/setup_backup_$(date +%Y%m%d_%H%M%S)"

# Logging setup
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> >(tee -a "$LOG_FILE") 2> >(tee -a "$ERROR_LOG" >&2)


# Backup existing configurations
backup_configs() {
    echo "📦 Backing up existing configurations..."
    mkdir -p "$BACKUP_DIR"
    # Backup .zshrc if exists
    [ -f ~/.zshrc ] && cp ~/.zshrc "$BACKUP_DIR/.zshrc.bak"
    # Backup .env if exists
    [ -f .env ] && cp .env "$BACKUP_DIR/.env.bak"
    echo "✅ Configurations backed up to $BACKUP_DIR"
}

# Enhanced error handling for each function
handle_error() {
    local function_name=$1
    local exit_code=$2
    echo "❌ Error in $function_name (exit code: $exit_code)"
    echo "Check $ERROR_LOG for details"
    # Add specific recovery steps here
    return $exit_code
}

# Enhanced installation verification
verify_installation() {
    local tool=$1
    case $tool in
        "postgres")
            pg_isready -q || return 1
            ;;
        "redis")
            redis-cli ping | grep -q "PONG" || return 1
            ;;
    esac
    return 0
}

# Add progress indicators
show_progress() {
    local step=$1
    local total=$2
    local width=50
    local percent=$((step * 100 / total))
    local filled=$((width * step / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr " " "="
    printf "%${empty}s" | tr " " " "
    printf "] %d%%" $percent
}

check_if_rosetta_present() {
    echo "🔍 Checking Rosetta installation..."
    if /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "✅ Rosetta is already installed."
    else
        echo "🚀 Installing Rosetta..."
        softwareupdate --install-rosetta --agree-to-license
        if [ $? -eq 0 ]; then
            echo "✅ Rosetta installation successful."
        else
            echo "❌ Failed to install Rosetta."
            return 1
        fi
    fi
}

install_homebrew() {
    echo "🔍 Checking Homebrew installation..."
    if ! command -v brew &>/dev/null; then
        echo "🚀 Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "✅ Homebrew is already installed. Version: $(brew --version)"
    fi
}

set_current_shell_arch_to_intel86() {
    echo "🔍 Checking current shell architecture..."
    CURRENT_ARCH=$(arch)
    echo "📌 Current architecture: $CURRENT_ARCH"

    if [ "$CURRENT_ARCH" != "i386" ]; then
        echo "🔄 Setting up Intel x86_64 environment..."
        # Instead of switching shells, set up environment variables for Intel architecture
        export HOMEBREW_PREFIX="/usr/local"
        export HOMEBREW_CELLAR="/usr/local/Cellar"
        export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
        export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
        
        # Create an alias for running commands in Intel mode
        alias ibrew="arch -x86_64 /usr/local/bin/brew"
        
        echo "✅ Intel x86_64 environment configured."
        echo "ℹ️ Use 'ibrew' command for Intel-specific Homebrew operations."
    else
        echo "✅ Already running in x86_64 mode."
    fi
}

install_most_common_dev_deps() {
    echo "📦 Checking and installing development dependencies..."
    
    # Core CLI packages
    BREW_PACKAGES=(
        readline    # Line editing library
        sqlite3    # Lightweight database
        xz         # Data compression
        zlib       # Data compression library
        postgresql # Database server
        poppler    # PDF rendering library
        pyenv      # Python version manager
        pre-commit # Git hook manager
    )

    # GUI applications
    CASK_PACKAGES=(
        ngrok      # Local tunnel proxy
    )

    # Install CLI packages
    for package in "${BREW_PACKAGES[@]}"; do
        if [ "$(arch)" != "i386" ]; then
            if ibrew list "$package" &>/dev/null; then
                echo "✅ $package is already installed"
            else
                echo "📦 Installing $package..."
                ibrew install "$package"
            fi
        else
            if brew list "$package" &>/dev/null; then
                echo "✅ $package is already installed"
            else
                echo "📦 Installing $package..."
                brew install "$package"
            fi
        fi
    done

    # Install GUI applications
    for cask in "${CASK_PACKAGES[@]}"; do
        if [ "$(arch)" != "i386" ]; then
            if ibrew list --cask "$cask" &>/dev/null; then
                echo "✅ $cask is already installed"
            else
                echo "📦 Installing $cask..."
                ibrew install --cask "$cask"
            fi
        else
            if brew list --cask "$cask" &>/dev/null; then
                echo "✅ $cask is already installed"
            else
                echo "📦 Installing $cask..."
                brew install --cask "$cask"
            fi
        fi
    done
}

setup_postgres() {
    echo "🗄️ Setting up PostgreSQL..."
    
    # Check if PostgreSQL is already installed
    if [ "$(arch)" != "i386" ]; then
        if ibrew list postgresql &>/dev/null; then
            echo "✅ PostgreSQL is already installed"
        else
            echo "📦 Installing PostgreSQL..."
            ibrew install postgresql
        fi
        
        # Check if PostgreSQL service is already running
        if ibrew services list | grep -q "postgresql.*started"; then
            echo "✅ PostgreSQL service is already running"
        else
            echo "🚀 Starting PostgreSQL service..."
            ibrew services start postgresql
        fi
    else
        if brew list postgresql &>/dev/null; then
            echo "✅ PostgreSQL is already installed"
        else
            echo "📦 Installing PostgreSQL..."
            brew install postgresql
        fi
        
        if brew services list | grep -q "postgresql.*started"; then
            echo "✅ PostgreSQL service is already running"
        else
            echo "🚀 Starting PostgreSQL service..."
            brew services start postgresql
        fi
    fi

    # Check if postgres user exists
    if psql -U postgres -c "SELECT 1" &>/dev/null; then
        echo "✅ PostgreSQL superuser already exists"
    else
        echo "👤 Creating PostgreSQL superuser..."
        createuser -s postgres
    fi
    
    echo "⏳ Waiting for PostgreSQL service to initialize..."
    echo "Press Enter when you're ready to proceed with database creation..."
    read -r
    
    # Check if database already exists
    if psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "spotdraft-django-rest-api"; then
        echo "✅ Database 'spotdraft-django-rest-api' already exists"
    else
        echo "💾 Creating default database..."
        psql -U postgres -c 'CREATE DATABASE "spotdraft-django-rest-api";'
    fi
}

setup_redis() {
    echo "🔴 Setting up Redis..."
    if [ "$(arch)" != "i386" ]; then
        ibrew list redis &>/dev/null || ibrew install redis
        ibrew services start redis || {
            echo "❌ Failed to start Redis service"
            return 1
        }
    else
        brew list redis &>/dev/null || brew install redis
        brew services start redis || {
            echo "❌ Failed to start Redis service"
            return 1
        }
    fi
}
# Fix libxmlsec1 installation
install_libxmlsec1() {
    echo "📦 Installing libxmlsec1..."
    export DESIRED_SHA="7f35e6ede954326a10949891af2dba47bbe1fc17"
    TEMP_DIR=$(mktemp -d)
    FORMULA_PATH="$TEMP_DIR/libxmlsec1.rb"

    curl -fsSL "https://raw.githubusercontent.com/Homebrew/homebrew-core/${DESIRED_SHA}/Formula/libxmlsec1.rb" -o "$FORMULA_PATH" || {
        echo "❌ Failed to download libxmlsec1 formula"
        return 1
    }

    sed -i.bak 's|url ".*"|url "https://www.aleksey.com/xmlsec/download/older-releases/xmlsec1-1.2.37.tar.gz"|' "$FORMULA_PATH"

    if [ "$(arch)" != "i386" ]; then
        ibrew install --build-from-source --formula "$FORMULA_PATH" || {
            echo "❌ Failed to install libxmlsec1"
            return 1
        }
    else
        brew install --build-from-source --formula "$FORMULA_PATH" || {
            echo "❌ Failed to install libxmlsec1"
            return 1
        }
    fi
}
# Fix duplicate credentials error while doing migrations
fix_duplicate_credentials() {
    echo "🔧 Fixing duplicate credentials..."
    psql -U postgres -d "spotdraft-django-rest-api" -q -c "
        UPDATE integrations_v2_nativeintegrationcredential
        SET name = name || '_' || id
        WHERE id IN (
            SELECT id FROM (
                SELECT id, ROW_NUMBER() OVER (PARTITION BY name ORDER BY id) as rn
                FROM integrations_v2_nativeintegrationcredential
            ) t WHERE rn > 1
        );" 2>/dev/null
}

# Main execution with enhanced features
main() {
    local total_steps=6
    local current_step=0
    
    echo "🚀 Starting setup process..."
    backup_configs
    
    ((current_step++))
    show_progress $current_step $total_steps
    check_if_rosetta_present || handle_error "check_if_rosetta_present" $?
    
    ((current_step++))
    show_progress $current_step $total_steps
    install_homebrew || handle_error "install_homebrew" $?
    
    ((current_step++))
    show_progress $current_step $total_steps
    set_current_shell_arch_to_intel86 || handle_error "set_current_shell_arch_to_intel86" $?
    
    ((current_step++))
    show_progress $current_step $total_steps
    install_most_common_dev_deps || handle_error "install_most_common_dev_deps" $?
    
    ((current_step++))
    show_progress $current_step $total_steps
    install_libxmlsec1 || handle_error "install_libxmlsec1" $?
    
    ((current_step++))
    show_progress $current_step $total_steps
    setup_postgres || handle_error "setup_postgres" $?
    setup_redis || handle_error "setup_redis" $?
    
    fix_duplicate_credentials || handle_error "fix_duplicate_credentials" $?
    
    echo -e "\n✅ Setup completed successfully!"
    echo "📝 Logs available in $LOG_FILE"
    echo "❌ Errors (if any) in $ERROR_LOG"
    echo "📦 Backups in $BACKUP_DIR"
}

main "$@"