# Local Development Setup

## Prerequisites

Before running the setup script:

1. Clone the Django REST API repository
2. Navigate to the repository root directory

```bash
cd /path/to/django-rest-api
```

## Quick Start

### 1. Run the setup script

From the repository root directory, run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sonu-spotdraft/local-dev-setup/refs/heads/main/be-setup.sh)"
```

The script will create a `.env` file with local development configuration:

```bash
CACHE_BACKEND=django_redis.cache.RedisCache
CACHE_LOCATION=redis://127.0.0.1:6379/1
DEBUG=True
CLUSTER_URL=http://localhost:8000/
CELERY_BROKER_URL=redis://127.0.0.1:6379/0
AWS_ACCESS_KEY_ID=fake
AWS_SECRET_ACCESS_KEY=fake%
```

### 2. Set up environment variables

Add these to your `.zshrc` or `.bashrc` if not already present:

```bash
# Homebrew
eval "$(/usr/local/bin/brew shellenv)"
alias ibrew="arch -x86_64 /usr/local/bin/brew"

# Python
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
alias ipyenv="arch -x86_64 pyenv"
alias ipython="arch -x86_64 python"  # Alias for running Python in Intel mode

export LDFLAGS="-L/usr/local/opt/zlib/lib"
export CPPFLAGS="-I/usr/local/opt/zlib/include"
export LDFLAGS="-L/usr/local/opt/openssl@3/lib"
export CPPFLAGS="-I/usr/local/opt/openssl@3/include"

```

### 3. Django Setup

1. Get the latest database dump from dev-ops and import it:

   ```bash
   psql spotdraft-django-rest-api < path/to/db_dump
   ```

2. Run Django setup commands one by one :
   don't forget to run `source env/bin/activate` if not already activated
   ```bash
   # Run these commands with arch -x86_64 prefix to ensure Intel compatibility
   # If you have ipython alias in your .zshrc, you can use ipython instead of arch -x86_64 python
   ipython manage.py migrate
   ipython manage.py createsuperuser  # if not already created
   ipython manage.py runserver
   ```

## Notes

- The `.env` file is required for local development
- Environment variables need to be added to your shell config file
- Database dump is required for initial setup
- All Python commands should be run in Intel architecture mode
  - Use `ipython` alias for running Python commands in Intel mode
  - Any command can be run in Intel mode by prefixing it with `arch -x86_64`
- Always activate virtual environment before running Django commands: `source env/bin/activate`
- If you encounter architecture-related issues, verify you're using Intel mode with `arch` command
