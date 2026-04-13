# OpenMRS Tajikistan

This project provides a Dockerized setup for OpenMRS, specifically configured for the Tajikistan implementation.

## Prerequisites

- Docker and Docker Compose installed on your machine.
- A running MySQL database (version 8 is recommended).

## Setup Instructions

1.  **OpenMRS WAR File:**
    - Place your `openmrs.war` file in the root directory of this project.
    - **Important:** The `openmrs.war` file should be **version 2.8.x**.

2.  **Environment Configuration:**
    - Copy the `.env-example` file to a new file named `.env`:
      ```bash
      cp .env-example .env
      ```
    - Open the `.env` file and update the database credentials and host port according to your environment.
    - If your MySQL database is running on the host machine, use `host.docker.internal` (Windows/Mac) as the `OPENMRS_DB_HOST`.

3.  **Modules:**
    - The `modules/` directory should contain the necessary `.omod` files for the Tajikistan implementation. These will be automatically copied to the OpenMRS runtime directory during container startup.

4.  **Database Initialization:**
    - The `openmrs_schema.sql` and `openmrs_seed.sql` files in the root directory are used to initialize the database if it's empty (i.e., if the `users` table is not found).

## Running the Project

To build and start the OpenMRS container, run:

```bash
docker-compose up --build -d
```

The application will be accessible at: `http://localhost:8080/openmrs` (or the port specified in your `.env` file).

## Project Structure

- `Dockerfile`: Defines the Tomcat-based Docker image for OpenMRS.
- `docker-compose.yml`: Orchestrates the OpenMRS container.
- `entrypoint.sh`: Handles environment variable substitution in `openmrs-runtime.properties`, waits for the database, and initializes it if necessary.
- `modules/`: Directory for OpenMRS modules (`.omod` files).
- `openmrs-runtime.properties.template`: Template for the OpenMRS runtime configuration.
- `openmrs_schema.sql` / `openmrs_seed.sql`: SQL scripts for initial database setup.
- `.env-example`: Example environment variables file.
