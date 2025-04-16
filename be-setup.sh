#!/bin/bash

# Enhanced error handling
set -e
set -o pipefail

# Configuration
readonly LOG_FILE="setup.log"
readonly ERROR_LOG="setup_errors.log"
readonly BACKUP_DIR="$HOME/setup_backup_$(date +%Y%m%d_%H%M%S)"
readonly DB_NAME="spotdraft-django-rest-api"

# Logging setup
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> >(tee -a "$LOG_FILE") 2> >(tee -a "$ERROR_LOG" >&2)

# Backup existing configurations
backup_configs() {
    echo "📦 Backing up existing configurations..."
    mkdir -p "$BACKUP_DIR"
    [ -f ~/.zshrc ] && cp ~/.zshrc "$BACKUP_DIR/.zshrc.bak"
    [ -f .env ] && cp .env "$BACKUP_DIR/.env.bak"
    echo "✅ Configurations backed up to $BACKUP_DIR"
}

# Enhanced error handling for each function
handle_error() {
    local function_name=$1
    local exit_code=$2
    echo "❌ Error in $function_name (exit code: $exit_code)"
    echo "Check $ERROR_LOG for details"
    return $exit_code
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
    
    # Initialize Homebrew environment
    eval "$(/usr/local/bin/brew shellenv)"
    
    # Set up Intel mode Homebrew
    export HOMEBREW_PREFIX="/usr/local"
    export HOMEBREW_CELLAR="/usr/local/Cellar"
    export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
    export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
    
    # Create and export the ibrew function instead of an alias
    ibrew() {
        arch -x86_64 /usr/local/bin/brew "$@"
    }
    export -f ibrew
    
    echo "✅ Homebrew Intel mode configured. Use 'ibrew' for Intel-specific operations."
}

set_current_shell_arch_to_intel86() {
    echo "🔍 Checking current shell architecture..."
    CURRENT_ARCH=$(arch)
    echo "📌 Current architecture: $CURRENT_ARCH"

    if [ "$CURRENT_ARCH" != "i386" ]; then
        echo "🔄 Setting up Intel x86_64 environment..."
        export HOMEBREW_PREFIX="/usr/local"
        export HOMEBREW_CELLAR="/usr/local/Cellar"
        export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
        export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
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
        swig
    )

    # GUI applications
    CASK_PACKAGES=(
        ngrok      # Local tunnel proxy
    )

    # Install CLI packages
    for package in "${BREW_PACKAGES[@]}"; do
        if ibrew list "$package" &>/dev/null; then
            echo "✅ $package is already installed"
        else
            echo "📦 Installing $package..."
            ibrew install "$package"
        fi
    done

    # Install GUI applications
    for cask in "${CASK_PACKAGES[@]}"; do
        if ibrew list --cask "$cask" &>/dev/null; then
            echo "✅ $cask is already installed"
        else
            echo "📦 Installing $cask..."
            ibrew install --cask "$cask"
        fi
    done

    # Configure pyenv for Python version management
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    # Initialize pyenv shell integration
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    # Run pyenv in Intel mode (x86_64)
    alias ipyenv="arch -x86_64 pyenv"
}

setup_postgres() {
    echo "🗄️ Setting up PostgreSQL..."
    
    # Check if PostgreSQL is already installed
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
    if psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "✅ Database '$DB_NAME' already exists"
    else
        echo "💾 Creating default database..."
        psql -U postgres -c "CREATE DATABASE \"$DB_NAME\";"
    fi
}

setup_redis() {
    echo "🔴 Setting up Redis..."
    ibrew list redis &>/dev/null || ibrew install redis
    ibrew services start redis || {
        echo "❌ Failed to start Redis service"
        return 1
    }
}

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

    ibrew install --build-from-source --formula "$FORMULA_PATH" || {
        echo "❌ Failed to install libxmlsec1"
        return 1
    }

    # Configure XML libraries
    export PKG_CONFIG_PATH="/usr/local/opt/libxml2/lib/pkgconfig:/usr/local/opt/libxslt/lib/pkgconfig:/usr/local/opt/openssl@3.0/lib/pkgconfig:/usr/local/Cellar/libxmlsec1/1.2.37/lib/pkgconfig"
    export PATH="/usr/local/opt/libxml2/bin:$PATH"
    export DYLD_LIBRARY_PATH="/usr/local/Cellar/libxmlsec1/1.2.37/lib:$DYLD_LIBRARY_PATH"
    export PATH="/usr/local/Cellar/libxmlsec1/1.3.7/bin:$PATH"
}

fix_duplicate_credentials() {
    echo "🔧 Fixing duplicate credentials..."
    psql -U postgres -d "$DB_NAME" -q -c "
        UPDATE integrations_v2_nativeintegrationcredential
        SET name = name || '_' || id
        WHERE id IN (
            SELECT id FROM (
                SELECT id, ROW_NUMBER() OVER (PARTITION BY name ORDER BY id) as rn
                FROM integrations_v2_nativeintegrationcredential
            ) t WHERE rn > 1
        );" 2>/dev/null
}

create_env_file() {
    echo "📝 Creating .env file..."
    cat > .env << EOF
CACHE_BACKEND=django_redis.cache.RedisCache
CACHE_LOCATION=redis://127.0.0.1:6379/1
DEBUG=True
CLUSTER_URL=http://localhost:8001/
CELERY_BROKER_URL=redis://127.0.0.1:6379/0
AWS_ACCESS_KEY_ID=fake
AWS_SECRET_ACCESS_KEY=fake%
EOF
    echo "✅ .env file created successfully"
}

setup_poetry() {
    echo "🐍 Setting up Poetry..."
    alias ipython="arch -x86_64 python"  # Alias for running Python in Intel mode
    # Check if Poetry is already installed
    if command -v poetry &>/dev/null; then
        echo "✅ Poetry is already installed. Version: $(poetry --version)"
    else
        echo "📦 Installing Poetry..."
        export POETRY_VERSION=1.4.0
        curl -sSL https://raw.githubusercontent.com/python-poetry/install.python-poetry.org/e8d8f76750e1abaebd628e2323a49163d102c9d6/install-poetry.py | ipython -
        export PATH="$HOME/.local/bin:$PATH"
    fi
    arch -x86_64 python -m venv env
    source env/bin/activate
    poetry config virtualenvs.create false
    poetry install
    echo "✅ Poetry setup completed successfully"
}

# Main execution
main() {
    echo "🚀 Starting setup process..."
    
    # System setup
    check_if_rosetta_present || handle_error "check_if_rosetta_present" $?
    install_homebrew || handle_error "install_homebrew" $?
    set_current_shell_arch_to_intel86 || handle_error "set_current_shell_arch_to_intel86" $?
    
    # Package installation
    install_most_common_dev_deps || handle_error "install_most_common_dev_deps" $?
    install_libxmlsec1 || handle_error "install_libxmlsec1" $?
    
    # Database setup
    setup_postgres || handle_error "setup_postgres" $?
    setup_redis || handle_error "setup_redis" $?
    
    # Python setup
    echo "🐍 Setting up Python 3.10.11..."
    ipyenv install 3.10.11 --skip-existing || handle_error "pyenv_install" $?

    # Create .env file
    create_env_file || handle_error "create_env_file" $?
    
    install_libxmlsec1 || handle_error "install_libxmlsec1" $?
    setup_poetry || handle_error "setup_poetry" $?

    echo -e "\n✅ Setup completed successfully!"
    echo "📝 Logs available in $LOG_FILE"
    echo "❌ Errors (if any) in $ERROR_LOG"
    echo "📦 Backups in $BACKUP_DIR"
}

main "$@"