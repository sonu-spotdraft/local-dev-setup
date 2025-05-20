#!/bin/bash

# Enhanced error handling
set -e
set -o pipefail

echo "arch: $(arch)"

# Function to print colored output
print_message() {
    echo -e "\033[1;32m$1\033[0m"
}

print_error() {
    echo -e "\033[1;31m$1\033[0m"
}

# Handle Ctrl+C
trap 'print_error "\nScript interrupted by user. Exiting..."; exit 1' INT

# Check if script is run with sudo
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script with sudo. It will prompt for sudo access when needed."
    exit 1
fi

# Check and install Rosetta if needed
if ! /usr/bin/arch -x86_64 /usr/bin/true &> /dev/null; then
    print_message "Rosetta is not installed. Installing Rosetta..."
    print_message "You may be prompted for your password to install Rosetta..."
    if /usr/sbin/softwareupdate --install-rosetta --agree-to-license; then
        print_message "Rosetta installed successfully"
    else
        print_error "Failed to install Rosetta. Please ensure you have the necessary permissions."
        exit 1
    fi
else
    print_message "Rosetta is already installed"
fi

# Check if running on macOS
if [[ "$(uname -m)" != "x86_64" ]]; then
    print_error "This script is designed for Intel only"
    # exit 1
fi

# Define Intel-specific paths
INTEL_BREW_PATH="/usr/local/bin/brew"
INTEL_BREW_PREFIX="/usr/local"

# Check and install Intel Homebrew
if ! command -v $INTEL_BREW_PATH &> /dev/null; then
    print_message "Installing Intel Homebrew..."
    arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_message "Intel Homebrew is already installed"
fi

# Get Homebrew prefix for Intel
BREW_PREFIX=$(arch -x86_64 $INTEL_BREW_PATH --prefix)
export POETRY_VERSION=1.4.0

echo "BREW_PREFIX: $BREW_PREFIX"

#if brew doctor output error , else print ready to brew 
if arch -x86_64 $INTEL_BREW_PATH doctor &> /dev/null; then
    print_message "Ready to brew"
fi

# Set up Homebrew shell environment for Intel only
print_message "Setting up Intel Homebrew environment..."
eval "$(arch -x86_64 $INTEL_BREW_PATH shellenv)"

# Install required packages using Intel Homebrew
print_message "Installing required packages using Intel Homebrew..."
HOMEBREW_NO_INSTALL_UPGRADE=1 arch -x86_64 $INTEL_BREW_PATH install openssl readline sqlite3 xz zlib postgresql redis libxml2 libxslt libxmlsec1 poppler swig pyenv pre-commit tcl-tk@8 libb2

setup_pyenv() {
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"

    # Initialize pyenv for current session only
    if command -v $INTEL_BREW_PREFIX/bin/pyenv &> /dev/null; then
        # Set up pyenv environment
        export PYENV_SHELL="zsh"
        export PATH="$PYENV_ROOT/shims:$PATH"
        export PYENV_VERSION=""
        
        # Add pyenv to PATH
        export PATH="$PYENV_ROOT/bin:$PATH"
        
        # Initialize pyenv
        eval "$($INTEL_BREW_PREFIX/bin/pyenv init --path)"
        eval "$($INTEL_BREW_PREFIX/bin/pyenv init -)"
        
        # Verify pyenv is working
        if ! $INTEL_BREW_PREFIX/bin/pyenv versions &> /dev/null; then
            print_error "Failed to initialize pyenv. Please check your installation."
            exit 1
        fi
    else
        print_error "pyenv not found at $INTEL_BREW_PREFIX/bin/pyenv"
        exit 1
    fi
}

setup_pyenv

# PostgreSQL setup using Intel Homebrew
print_message "Setting up PostgreSQL..."
if ! command -v $INTEL_BREW_PREFIX/bin/postgres &> /dev/null; then
    print_message "Installing PostgreSQL..."
    arch -x86_64 $INTEL_BREW_PATH install postgresql
else
    print_message "PostgreSQL is already installed"
fi

# Start PostgreSQL if not running
if ! $INTEL_BREW_PREFIX/bin/pg_isready &> /dev/null; then
    print_message "Starting PostgreSQL..."
    arch -x86_64 $INTEL_BREW_PATH services start postgresql
    sleep 5  # Wait for PostgreSQL to start
else
    print_message "PostgreSQL is already running"
fi

# Create postgres user if it doesn't exist
if ! $INTEL_BREW_PREFIX/bin/psql -U postgres -c "SELECT 1" &> /dev/null; then
    print_message "Creating postgres user..."
    $INTEL_BREW_PREFIX/bin/createuser -s postgres
else
    print_message "postgres user already exists"
fi

# Create database if it doesn't exist
print_message "Setting up database..."
if ! $INTEL_BREW_PREFIX/bin/psql -U postgres -lqt | cut -d \| -f 1 | grep -qw spotdraft-django-rest-api; then
    print_message "Creating spotdraft-django-rest-api database..."
    $INTEL_BREW_PREFIX/bin/createdb -U postgres spotdraft-django-rest-api
else
    print_message "spotdraft-django-rest-api database already exists"
fi

# Redis setup using Intel Homebrew
print_message "Setting up Redis..."
if ! command -v $INTEL_BREW_PREFIX/bin/redis-cli &> /dev/null; then
    print_message "Installing Redis..."
    arch -x86_64 $INTEL_BREW_PATH install redis
else
    print_message "Redis is already installed"
fi

# Start Redis if not running
if ! arch -x86_64 $INTEL_BREW_PREFIX/bin/redis-cli ping &> /dev/null; then
    print_message "Starting Redis..."
    arch -x86_64 $INTEL_BREW_PATH services start redis
    sleep 2  # Wait for Redis to start
else
    print_message "Redis is already running"
fi

# Set up environment variables for installed packages
print_message "Setting up environment variables..."
# Development libraries paths
# SSL and Security required for pyenv and libxmlsec1
export LDFLAGS="-L$BREW_PREFIX/opt/openssl@3/lib"
export CPPFLAGS="-I$BREW_PREFIX/opt/openssl@3/include"
export PKG_CONFIG_PATH="$BREW_PREFIX/opt/openssl@3/lib/pkgconfig"

# XML and XSLT required for libxmlsec1 
export LDFLAGS="$LDFLAGS -L$BREW_PREFIX/opt/libxslt/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_PREFIX/opt/libxslt/include"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BREW_PREFIX/opt/libxml2/lib/pkgconfig:$BREW_PREFIX/opt/libxslt/lib/pkgconfig"

# Compression libraries required for pyenv
export LDFLAGS="$LDFLAGS -L$BREW_PREFIX/opt/zlib/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_PREFIX/opt/zlib/include"

# Database required for pyenv
export LDFLAGS="$LDFLAGS -L$BREW_PREFIX/opt/sqlite/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_PREFIX/opt/sqlite/include"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BREW_PREFIX/opt/sqlite/lib/pkgconfig"

# Readline required for pyenv
export LDFLAGS="$LDFLAGS -L$BREW_PREFIX/opt/readline/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_PREFIX/opt/readline/include"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BREW_PREFIX/opt/readline/lib/pkgconfig"

# XZ required for libxmlsec1
export LDFLAGS="$LDFLAGS -L$BREW_PREFIX/opt/xz/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_PREFIX/opt/xz/include"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BREW_PREFIX/opt/xz/lib/pkgconfig"

# Tcl-Tk required for pyenv
export LDFLAGS="$LDFLAGS -L$BREW_PREFIX/opt/tcl-tk/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_PREFIX/opt/tcl-tk/include"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BREW_PREFIX/opt/tcl-tk/lib/pkgconfig"

# libxml2 required for libxmlsec1
export LDFLAGS="-L$BREW_PREFIX/opt/libxml2/lib $LDFLAGS"
export CPPFLAGS="-I$BREW_PREFIX/opt/libxml2/include $CPPFLAGS"
export PKG_CONFIG_PATH="$BREW_PREFIX/opt/libxml2/lib/pkgconfig:$PKG_CONFIG_PATH"

# Add all paths to PATH
export PATH="$BREW_PREFIX/opt/openssl@3/bin:$PATH"
export PATH="$BREW_PREFIX/opt/sqlite/bin:$PATH"
export PATH="$BREW_PREFIX/opt/readline/bin:$PATH"
export PATH="$BREW_PREFIX/opt/xz/bin:$PATH"
export PATH="$BREW_PREFIX/opt/zlib/bin:$PATH"
export PATH="$BREW_PREFIX/opt/tcl-tk/bin:$PATH"
export PATH="$BREW_PREFIX/opt/libxmlsec1/bin:$PATH"

print_message "Environment variables set up completed"

# Python environment setup
print_message "Setting up Python environment..."



# Check if Intel pyenv is installed
if command -v $INTEL_BREW_PREFIX/bin/pyenv &> /dev/null; then
    print_message "Intel pyenv is already installed, checking Python versions..."
    
    # Store existing Python versions
    EXISTING_VERSIONS=$($INTEL_BREW_PREFIX/bin/pyenv versions --bare)
    
    # Check if .python-version exists and get required version
    if [ -f .python-version ]; then
        REQUIRED_VERSION=$(cat .python-version)
        print_message "Required Python version: $REQUIRED_VERSION"
        
        # Check if required version is installed and its architecture
        if $INTEL_BREW_PREFIX/bin/pyenv versions | grep -q "$REQUIRED_VERSION"; then
            if ! command -v python &> /dev/null; then
                print_message "Python is not installed. Installing Python version $REQUIRED_VERSION..."
                #  uninstall required version first for deleting existing installation only if its exist in the system 
                if $INTEL_BREW_PREFIX/bin/pyenv versions | grep -q "$REQUIRED_VERSION"; then
                    $INTEL_BREW_PREFIX/bin/pyenv uninstall -f $REQUIRED_VERSION
                fi
                $INTEL_BREW_PREFIX/bin/pyenv install $REQUIRED_VERSION
                if [ $? -ne 0 ]; then
                    print_error "Failed to install Python $REQUIRED_VERSION"
                    exit 1
                fi
            fi
            
            PYTHON_ARCH=$(arch -x86_64 python -c "import platform; print(platform.machine())")
            if [ "$PYTHON_ARCH" != "x86_64" ]; then
                print_message "Python $REQUIRED_VERSION is installed but not on x86_64 architecture"
                print_message "Removing Intel pyenv installation..."

                arch -x86_64 $INTEL_BREW_PATH uninstall pyenv 

                # Remove Intel pyenv
                rm -rf "$HOME/.pyenv"
                
                # Remove pyenv from shell configuration
                if [ -f "$HOME/.zshrc" ]; then
                    sed -i.bak '/pyenv/d' "$HOME/.zshrc"
                    sed -i.bak '/pyenv/d' "$HOME/.zprofile"
                fi
                if [ -f "$HOME/.bash_profile" ]; then
                    sed -i.bak '/pyenv/d' "$HOME/.bash_profile"
                fi
                
                print_message "Intel pyenv removed successfully"
            else
                print_message "Python $REQUIRED_VERSION is already installed with x86_64 architecture"
            fi
        else
            print_message "Required Python version $REQUIRED_VERSION is not installed"
        fi
    else
        print_error ".python-version file not found"
        exit 1
    fi
else
    print_message "Intel pyenv is not installed"
fi

install_libxmlsec1() {
    # First unlink libxmlsec1
    echo "📦 Unlinking libxmlsec1..."
    arch -x86_64 $INTEL_BREW_PATH unlink libxmlsec1 2>/dev/null || true
    
    # Then uninstall it
    echo "📦 Uninstalling libxmlsec1..."
    arch -x86_64 $INTEL_BREW_PATH uninstall --force libxmlsec1 2>/dev/null || true
    
    # Install libxmlsec1
    export DESIRED_SHA="7f35e6ede954326a10949891af2dba47bbe1fc17"
    TEMP_DIR=$(mktemp -d)
    FORMULA_PATH="$TEMP_DIR/libxmlsec1.rb"
    
    # Download the formula directly from Homebrew's repository
    curl -fsSL "https://raw.githubusercontent.com/Homebrew/homebrew-core/${DESIRED_SHA}/Formula/libxmlsec1.rb" -o "$FORMULA_PATH" || {
        echo "❌ Failed to download libxmlsec1 formula"
        return 1
    }
    
    # Update OpenSSL version from 1.1 to 3
    sed -i.bak 's/openssl@1.1/openssl@3/g' "$FORMULA_PATH"
    echo "📦 Updated OpenSSL dependency from 1.1 to 3"
    
    # Update the URL to use the older-releases path
    sed -i.bak 's|url ".*/download/xmlsec1-1.2.37.tar.gz"|url "https://www.aleksey.com/xmlsec/download/older-releases/xmlsec1-1.2.37.tar.gz"|' "$FORMULA_PATH"
    echo "📦 Updated URL to use older-releases path"
    
    # Update the openssl path in install args
    sed -i.bak 's|--with-openssl=#{Formula\["openssl@1.1"\]|--with-openssl=#{Formula\["openssl@3"\]|' "$FORMULA_PATH"
    echo "📦 Updated OpenSSL path in install args"
    
    # Force install from source
    arch -x86_64 $INTEL_BREW_PATH install --build-from-source --formula "$FORMULA_PATH" || {
        echo "❌ Failed to install libxmlsec1"
        return 1
    }
    
    # Clean up
    rm -rf "$TEMP_DIR"
    echo "✅ libxmlsec1 installed successfully"
    arch -x86_64 $INTEL_BREW_PATH pin libxmlsec1
}

install_poetry() {
    print_message "Installing Poetry..."
    PYTHON_PATH=$(which python)
    PYTHON_VERSION=$(python --version)
    print_message "Using $PYTHON_PATH ($PYTHON_VERSION) to install Poetry..."
    curl -sSL https://raw.githubusercontent.com/python-poetry/install.python-poetry.org/e8d8f76750e1abaebd628e2323a49163d102c9d6/install-poetry.py | arch -x86_64 python -
}

remove_poetry() {
    print_message "Removing existing Poetry installation..."
    PYTHON_PATH=$(which python)
    PYTHON_VERSION=$(python --version)
    print_message "Using $PYTHON_PATH ($PYTHON_VERSION) to install Poetry..."
    curl -sSL https://raw.githubusercontent.com/python-poetry/install.python-poetry.org/e8d8f76750e1abaebd628e2323a49163d102c9d6/install-poetry.py | arch -x86_64 python - --uninstall
    # Remove Poetry binary from various possible locations
    rm -rf /Users/sonu/Library/Application\ Support/pypoetry

    if [ -f "$HOME/Library/Application\ Support/pypoetry" ]; then
        rm -rf "$HOME/Library/Application\ Support/pypoetry"
        echo "Removed $HOME/Library/Application\ Support/pypoetry"
    fi
    if [ -d "$HOME/Library/Caches/pypoetry" ]; then
        rm -rf "$HOME/Library/Caches/pypoetry"
        echo "Removed $HOME/Library/Caches/pypoetry"
    fi
    print_message "Poetry removal completed"
}

create_env_file() {
    if [ -f .env ]; then
        echo "📝 .env file already exists, skipping creation..."
        return
    fi
    
    echo "📝 Creating .env file..."
    cat > .env << 'EOF'
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

install_libxmlsec1

# Poetry installation
if command -v poetry &> /dev/null; then
    print_message "Poetry is already installed, removing existing installation..."
    remove_poetry
    print_message "Reinstalling Poetry..."
    install_poetry
else
    print_message "Installing Poetry..."
    install_poetry
fi

if [ -d "env" ]; then
    rm -rf env
fi

echo "python arch: $(arch -x86_64 python -c "import platform; print(platform.machine())")"

arch -x86_64 python -m venv env

source env/bin/activate 

# Verify virtual environment activation
if [ -z "$VIRTUAL_ENV" ]; then
    print_error "Failed to activate virtual environment"
    exit 1
else
    print_message "Virtual environment activated: $VIRTUAL_ENV"
    print_message "Python path: $(which python)"
    print_message "Python version: $(python --version)"
    print_message "Python architecture: $(arch -x86_64 python -c "import platform; print(platform.machine())")"
fi

create_env_file

poetry config virtualenvs.create false

print_message "Setup completed successfully!"
print_message "Please run the following commands to complete the setup:"
print_message "1. psql spotdraft-django-rest-api < dev_<date>.sql"
print_message "2. source env/bin/activate"
print_message "3. poetry install"
print_message "4. python manage.py migrate"
print_message "5. python manage.py runserver"

# print_message "\nTo enable pyenv in new terminal sessions, add the following to your shell configuration (.zshrc or .bash_profile):"
# print_message 'export PYENV_ROOT="$HOME/.pyenv"'
# print_message 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
# print_message 'eval "$(pyenv init -)"'
