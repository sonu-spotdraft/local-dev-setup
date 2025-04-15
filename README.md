# Local Development Setup

This guide helps you set up your local development environment for the project. The setup script (`be-setup.sh`) handles most of the configuration automatically.

## Quick Start

1. Clone the repository
2. Make the setup script executable:
   ```bash
   chmod +x be-setup.sh
   ```
3. Run the setup script:
   ```bash
   ./be-setup.sh
   ```

## For New Developers

1. Install necessary development tools
2. Set up the database
3. Configure your environment

### First-time Setup Tips

- The script will create backups of your existing configurations
- You'll need to press Enter when prompted during PostgreSQL setup
- If you're on Apple Silicon (M1/M2), the script will handle architecture-specific setup automatically

## For Existing Developers

The setup script has been updated with improved features:

### Recent Improvements

- Improved package installation checks
- Better PostgreSQL setup handling
- Architecture-aware installation
- Enhanced error handling and logging

## Manual Setup (Alternative)

If you prefer to set up manually or the automated script fails:

### 1. Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Development Tools

```bash
# Core development tools
brew install readline sqlite3 xz zlib postgresql poppler pyenv pre-commit

# GUI applications
brew install --cask ngrok
```

### 3. Set Up PostgreSQL

```bash
# Start PostgreSQL service
brew services start postgresql

# Create PostgreSQL superuser
createuser -s postgres

# Create database
createdb spotdraft-django-rest-api
```

### 4. Set Up Redis

```bash
brew install redis
brew services start redis
```

## Troubleshooting

### Common Issues

1. **PostgreSQL Connection Issues**

   - Ensure the service is running: `brew services list | grep postgresql`
   - Check if the postgres user exists: `psql -U postgres -c "SELECT 1"`

2. **Architecture-specific Issues**

   - On Apple Silicon, use `ibrew` for Intel-specific packages
   - Check your architecture: `arch`

### Logs and Backups

- Setup logs: `setup.log`
- Error logs: `setup_errors.log`
- Configuration backups: `~/setup_backup_YYYYMMDD_HHMMSS/`

## Contributing

If you find any issues or have suggestions for improvement:

1. Check the existing issues
2. Create a new issue with detailed information
3. Submit a pull request with your changes
