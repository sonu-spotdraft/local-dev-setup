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
arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sonu-spotdraft/local-dev-setup/refs/heads/main/be-setup.sh)"
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
