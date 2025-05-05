#!/bin/bash

# Enhanced error handling
set -e
set -o pipefail

# Function to print colored output
print_message() {
    echo -e "\033[1;32m$1\033[0m"
}

print_error() {
    echo -e "\033[1;31m$1\033[0m"
}

# Check if running on macOS
if [[ "$(uname -m)" != "x86_64" ]]; then
    print_error "This script is designed for Intel only"
    exit 1
fi

# Check and install Homebrew
if ! command -v brew &> /dev/null; then
    print_message "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_message "Homebrew is already installed"
fi

# Get Homebrew prefix based on architecture
BREW_PREFIX=$(brew --prefix)
export POETRY_VERSION=1.4.0

echo "BREW_PREFIX: $BREW_PREFIX"

#if brew doctor output error , else print ready to brew 
if brew doctor &> /dev/null; then
    print_message "Ready to brew"
fi

# Set up Homebrew shell environment based on architecture
if [[ "$(uname -m)" == "arm64" ]]; then
    print_message "Setting up Homebrew for Apple Silicon..."
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    print_message "Setting up Homebrew for Intel..."
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Install required packages
print_message "Installing required packages..."
brew install openssl readline sqlite3 xz zlib postgresql redis libxml2 libxslt libxmlsec1 poppler swig pyenv pre-commit tcl-tk@8 libb2

# PostgreSQL setup
print_message "Setting up PostgreSQL..."
if ! command -v postgres &> /dev/null; then
    print_message "Installing PostgreSQL..."
    brew install postgresql
else
    print_message "PostgreSQL is already installed"
fi

# Start PostgreSQL if not running
if ! pg_isready &> /dev/null; then
    print_message "Starting PostgreSQL..."
    brew services start postgresql
    sleep 5  # Wait for PostgreSQL to start
else
    print_message "PostgreSQL is already running"
fi

# Create postgres user if it doesn't exist
if ! psql -U postgres -c "SELECT 1" &> /dev/null; then
    print_message "Creating postgres user..."
    createuser -s postgres
else
    print_message "postgres user already exists"
fi

# Create database if it doesn't exist
print_message "Setting up database..."
if ! psql -U postgres -lqt | cut -d \| -f 1 | grep -qw spotdraft-django-rest-api; then
    print_message "Creating spotdraft-django-rest-api database..."
    createdb -U postgres spotdraft-django-rest-api
else
    print_message "spotdraft-django-rest-api database already exists"
fi

# Redis setup
print_message "Setting up Redis..."
if ! command -v redis-cli &> /dev/null; then
    print_message "Installing Redis..."
    brew install redis
else
    print_message "Redis is already installed"
fi

# Start Redis if not running
if ! redis-cli ping &> /dev/null; then
    print_message "Starting Redis..."
    brew services start redis
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
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# Install Python version from .python-version
if [ -f .python-version ]; then
    PYTHON_VERSION=$(cat .python-version)
    print_message "Checking Python version $PYTHON_VERSION..."
    
    if pyenv versions | grep -q "$PYTHON_VERSION"; then
        print_message "Python $PYTHON_VERSION is already installed"
    else
        print_message "Installing Python version $PYTHON_VERSION..."
        pyenv install -v $PYTHON_VERSION
    fi
else
    print_error ".python-version file not found"
    exit 1
fi

install_libxmlsec1() {
    # First unlink libxmlsec1
    echo "📦 Unlinking libxmlsec1..."
    brew unlink libxmlsec1 2>/dev/null || true
    
    # Then uninstall it
    echo "📦 Uninstalling libxmlsec1..."
    brew uninstall --force libxmlsec1 2>/dev/null || true
    
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
    brew install --build-from-source --formula "$FORMULA_PATH" || {
        echo "❌ Failed to install libxmlsec1"
        return 1
    }
    
    # Clean up
    rm -rf "$TEMP_DIR"
    echo "✅ libxmlsec1 installed successfully"
    brew pin libxmlsec1
}

install_poetry() {
    print_message "Installing Poetry..."
    PYTHON_PATH=$(which python)
    PYTHON_VERSION=$(python --version)
    print_message "Using $PYTHON_PATH ($PYTHON_VERSION) to install Poetry..."
    curl -sSL https://raw.githubusercontent.com/python-poetry/install.python-poetry.org/e8d8f76750e1abaebd628e2323a49163d102c9d6/install-poetry.py | python -
}

remove_poetry() {
    print_message "Removing existing Poetry installation..."
    PYTHON_PATH=$(which python)
    PYTHON_VERSION=$(python --version)
    print_message "Using $PYTHON_PATH ($PYTHON_VERSION) to install Poetry..."
    curl -sSL https://raw.githubusercontent.com/python-poetry/install.python-poetry.org/e8d8f76750e1abaebd628e2323a49163d102c9d6/install-poetry.py | python - --uninstall
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

python -m venv env

source env/bin/activate 

# Configure Poetry
print_message "Configuring Poetry..."


poetry config virtualenvs.create false

# Install dependencies
print_message "Installing project dependencies..."

poetry install

print_message "Backend setup completed successfully!"