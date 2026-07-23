# OpenMRS Tajikistan

This project provides a setup for OpenMRS and the MDR-TB Web application, configured for the Tajikistan implementation. It can be run via Docker Compose (recommended) or directly on the host.

## Architecture Overview

| Component | Technology | Default Port |
|-----------|-----------|-------------|
| OpenMRS | Tomcat + WAR | 8080 |
| MDR-TB Web | Django + Gunicorn | 8000 |
| Session cache | Redis | 6379 |
| Database | MySQL 8 | 3306 |

The MDR-TB Web app communicates with OpenMRS exclusively through the **OpenMRS REST API** (`/openmrs/ws/rest/v1/`). It does **not** connect to the database directly.

---

## Prerequisites

- **MySQL 8** running (on the host or remotely).
- For Docker: Docker and Docker Compose installed.
- For non-Docker: Python 3.10+, Redis, and a running OpenMRS instance.

---

## Docker Setup (Recommended)

### 1. OpenMRS WAR File

Place your `openmrs.war` (version **2.8.x**) in the root directory of this project.

### 2. Environment Configuration

```bash
cp .env-example .env
```

Edit `.env` and fill in your database credentials and port mappings (see [Environment Variables](#environment-variables) below).

If your MySQL database is running on the host machine, use `host.docker.internal` (Windows/Mac) as `OPENMRS_DB_HOST`.

### 3. Modules

Place the required `.omod` files in the `modules/` directory. They are automatically copied to the OpenMRS runtime directory on container startup.

### 4. Database Initialization

`openmrs_schema.sql` and `openmrs_seed.sql` in the root directory are used to initialize the database if it is empty (checked by looking for the `users` table).

### Run the Full Stack

```bash
docker-compose up --build -d
```

Services will be available at:

- **OpenMRS:** `http://localhost:8080/openmrs`
- **MDR-TB Web:** `http://localhost:8000`

### Run MDR-TB Web Only

```bash
docker-compose up --build -d mdrtb-web
```

> Docker Compose will automatically start the `openmrs` and `redis` containers that `mdrtb-web` depends on.

---

## Running Without Docker

Use this approach during local development or when you want to iterate on the MDR-TB Web app quickly without rebuilding containers.

### Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Python | 3.10+ | Match the Docker image |
| Redis | 7+ | Session cache; must be running before starting the app |
| OpenMRS | 2.8.x | Can be local or remote |

### Step 1 – Start Redis

Redis is required for Django session storage. Install and start it for your OS:

- **Windows:** Use the [Memurai](https://www.memurai.com/) Redis-compatible service, or run the official Redis Docker image: `docker run -d -p 6379:6379 redis:7-alpine`
- **macOS:** `brew install redis && brew services start redis`
- **Linux:** `sudo apt install redis-server && sudo systemctl start redis`

Verify Redis is running:
```bash
redis-cli ping
# should print: PONG
```

### Step 2 – Create a Python Virtual Environment

```bash
cd openmrs-module-mdrtb-web
python -m venv venv
```

Activate it:

- **Windows (PowerShell):** `.\venv\Scripts\Activate.ps1`
- **Windows (cmd):** `.\venv\Scripts\activate.bat`
- **macOS/Linux:** `source venv/bin/activate`

### Step 3 – Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 4 – Configure Environment Variables

The app reads a `.env` file from inside `openmrs-module-mdrtb-web/`. Create or edit it:

```bash
# openmrs-module-mdrtb-web/.env

SECRET_KEY=your-local-django-secret-key
DEBUG=True
REST_API_BASE_URL=http://127.0.0.1:8080/openmrs/ws/rest/v1/
```

See [MDR-TB Web Environment Variables](#mdrtb-web-environment-variables) for a full parameter reference.

> **Important:** `settings/settings.py` currently has `REST_API_BASE_URL` hardcoded to the production server. For local development, make sure your `.env` sets this to point to your local OpenMRS instance, **and** that the commented-out `os.getenv(...)` line in `settings.py` is used instead of the hardcoded value:
>
> ```python
> # settings/settings.py  ~line 157
> REST_API_BASE_URL = os.getenv("REST_API_BASE_URL", "http://127.0.0.1:8080/openmrs/ws/rest/v1/")
> ```

### Step 5 – Create the Logs Directory

Django's logging config writes to `logs/django.log`. Create the directory:

```bash
mkdir logs
```

### Step 6 – Run Migrations and Collect Static Files

```bash
python manage.py migrate
python manage.py collectstatic --noinput
```

### Step 7 – Start the Development Server

```bash
python manage.py runserver 0.0.0.0:8000
```

The app is now accessible at `http://localhost:8000`.

For production-like testing without Docker, use Gunicorn directly:

```bash
gunicorn --workers 8 --timeout 60 --bind 0.0.0.0:8000 settings.wsgi:application
```

> **Note:** `--timeout 60` is required if you plan to run the performance tests — without it, gunicorn's default 30-second timeout will cause the timeout test to fire at the wrong moment.

---

## Running Tests

Tests require `pytest-xdist` (already in `requirements.txt`) and run on **4 parallel workers** automatically via `pytest.ini`.

### Unit / integration tests

```bash
cd openmrs-module-mdrtb-web
pytest
```

### Performance tests

The performance tests in `tests/test_gunicorn_performance.py` send real HTTP requests to a live server. Before running them:

1. Start the server with `--timeout 60` (either via Docker or the gunicorn command above).
2. Set `DEBUG=True` in your `.env` — the `/test/slow` endpoint is disabled in production.
3. Optionally override the default connection details in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `MDRTB_WEB_URL` | `http://127.0.0.1:8000` | Base URL of the running server |
| `MDRTB_TEST_USERNAME` | `admin` | Login username |
| `MDRTB_TEST_PASSWORD` | `Admin123` | Login password |

Then run:

```bash
pytest tests/test_gunicorn_performance.py -v
```

---

## Environment Variables

### Root `.env` (Docker Compose)

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENMRS_DB_HOST` | `host.docker.internal` | MySQL host. Use `host.docker.internal` when MySQL runs on the host OS (Windows/Mac). On Linux use your machine's LAN IP. |
| `OPENMRS_DB_PORT` | `3306` | MySQL port. |
| `OPENMRS_DB_NAME` | `openmrs` | Name of the OpenMRS database. |
| `OPENMRS_DB_USER` | `openmrs` | MySQL user that OpenMRS connects as. |
| `OPENMRS_DB_PASSWORD` | `openmrs` | Password for `OPENMRS_DB_USER`. |
| `OPENMRS_HOST_PORT` | `8080` | Host port mapped to the Tomcat container. `http://localhost:<port>/openmrs` |
| `REDIS_HOST` | `redis` | Redis hostname inside the Docker network. |
| `REDIS_PORT` | `6379` | Redis port inside the Docker network. |
| `REDIS_HOST_PORT` | `6379` | Host port mapped to the Redis container. |
| `MDRTB_WEB_HOST_PORT` | `8000` | Host port mapped to the MDR-TB Web container. `http://localhost:<port>` |

### MDR-TB Web Environment Variables

These live in `openmrs-module-mdrtb-web/.env` (non-Docker) or are passed via `docker-compose.yml`.

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY` | **Yes** | Django [secret key](https://docs.djangoproject.com/en/4.1/ref/settings/#secret-key). Must be long, random, and kept secret in production. Never commit the real value. |
| `DEBUG` | No | `True` enables Django's debug error pages and verbose logging. **Never set `True` in production.** Defaults to `True` in `settings.py`. |
| `REST_API_BASE_URL` | **Yes** | Full base URL of the OpenMRS REST API, including the trailing slash. Example: `http://127.0.0.1:8080/openmrs/ws/rest/v1/`. In Docker Compose this is overridden to `http://openmrs:8080/openmrs/ws/rest/v1/` (internal service name). |
| `REDIS_LOCATION` | No | Redis connection string used for Django session caching. Format: `redis://<host>:<port>/<db>`. Defaults to `redis://127.0.0.1:6379/1` when `DEBUG=True`. In Docker Compose this is set to `redis://redis:6379/1`. |

---

## Project Structure

```
openmrs-tajikistan/
├── openmrs-module-mdrtb-web/   # Django MDR-TB Web application
│   ├── app/                    # Main Django app (views, models, templates)
│   ├── settings/               # Django settings and URL configuration
│   ├── tests/                  # Performance and integration tests
│   ├── requirements.txt        # Python dependencies
│   ├── pytest.ini              # Runs tests on 4 parallel workers (pytest-xdist)
│   ├── manage.py               # Django management CLI
│   ├── Dockerfile              # Container image (python:3.10-slim + gunicorn, 8 workers, 60s timeout)
│   └── .env                    # Local env vars (not committed)
├── openmrs-mdrtb-etl-job/      # ETL job for MDR-TB data processing
├── modules/                    # OpenMRS .omod module files
├── Dockerfile                  # Tomcat-based image for OpenMRS WAR
├── docker-compose.yml          # Orchestrates all services
├── entrypoint.sh               # Substitutes env vars, waits for DB, seeds if empty
├── openmrs-runtime.properties.template  # Template for OpenMRS runtime config
├── openmrs_schema.sql          # Initial database schema
├── openmrs_seed.sql            # Initial seed data
└── .env-example                # Copy to .env and fill in credentials
```
