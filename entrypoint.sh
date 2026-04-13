#!/bin/bash

# Define the template path and output path
TEMPLATE_FILE="/usr/local/tomcat/openmrs-runtime.properties.template"
OUTPUT_FILE="/root/.OpenMRS/openmrs-runtime.properties"

# Ensure the OpenMRS home directory exists
mkdir -p /root/.OpenMRS
mkdir -p /root/.OpenMRS/modules

# Copy modules from staging area to .OpenMRS/modules
if [ -d "/usr/local/tomcat/modules" ]; then
  echo "Copying modules to /root/.OpenMRS/modules..."
  cp /usr/local/tomcat/modules/*.omod /root/.OpenMRS/modules/ 2>/dev/null || true
fi

# Replace environment variables in the template
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

sed -i "s/\${OPENMRS_DB_HOST}/$OPENMRS_DB_HOST/g" "$OUTPUT_FILE"
sed -i "s/\${OPENMRS_DB_PORT}/$OPENMRS_DB_PORT/g" "$OUTPUT_FILE"
sed -i "s/\${OPENMRS_DB_NAME}/$OPENMRS_DB_NAME/g" "$OUTPUT_FILE"
sed -i "s/\${OPENMRS_DB_USER}/$OPENMRS_DB_USER/g" "$OUTPUT_FILE"
sed -i "s/\${OPENMRS_DB_PASSWORD}/$OPENMRS_DB_PASSWORD/g" "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE from $TEMPLATE_FILE"

# Wait for the database to be reachable
echo "Waiting for MySQL database at $OPENMRS_DB_HOST:$OPENMRS_DB_PORT..."
until mysql -h "$OPENMRS_DB_HOST" -P "$OPENMRS_DB_PORT" -u "$OPENMRS_DB_USER" -p"$OPENMRS_DB_PASSWORD" -e "SELECT 1" > /dev/null 2>&1; do
  echo "MySQL is unavailable - sleeping..."
  sleep 2
done

# Ensure the database exists
echo "Ensuring database $OPENMRS_DB_NAME exists..."
mysql -h "$OPENMRS_DB_HOST" -P "$OPENMRS_DB_PORT" -u "$OPENMRS_DB_USER" -p"$OPENMRS_DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $OPENMRS_DB_NAME CHARACTER SET utf8 COLLATE utf8_general_ci;"

# Check if we should execute the init script
# We'll check if the 'users' table exists, which is a core OpenMRS table.
# If it doesn't, we'll assume the DB needs initialization from the .sql file.
echo "Checking if database '$OPENMRS_DB_NAME' needs initialization..."
TABLE_EXISTS=$(mysql -h "$OPENMRS_DB_HOST" -P "$OPENMRS_DB_PORT" -u "$OPENMRS_DB_USER" -p"$OPENMRS_DB_PASSWORD" -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$OPENMRS_DB_NAME' AND table_name = 'users';")

if [ "$TABLE_EXISTS" -eq 0 ]; then
  echo "Database $OPENMRS_DB_NAME seems empty (no 'users' table). Executing SQL scripts..."
  
  echo "Executing openmrs_schema.sql..."
  mysql -h "$OPENMRS_DB_HOST" -P "$OPENMRS_DB_PORT" -u "$OPENMRS_DB_USER" -p"$OPENMRS_DB_PASSWORD" "$OPENMRS_DB_NAME" < /usr/local/tomcat/openmrs_schema.sql || echo "Warning: Error executing openmrs_schema.sql"
  echo "Successfully finished openmrs_schema.sql."

  echo "Executing openmrs_seed.sql..."
  mysql -h "$OPENMRS_DB_HOST" -P "$OPENMRS_DB_PORT" -u "$OPENMRS_DB_USER" -p"$OPENMRS_DB_PASSWORD" "$OPENMRS_DB_NAME" < /usr/local/tomcat/openmrs_seed.sql || echo "Warning: Error executing openmrs_seed.sql"
  echo "Successfully finished openmrs_seed.sql."
else
  echo "Database $OPENMRS_DB_NAME already contains data (found 'users' table). Skipping init scripts."
fi

# Start Tomcat
echo "Starting OpenMRS (Tomcat)..."
catalina.sh start

# Wait for OpenMRS web app to be ready
echo "Waiting for OpenMRS to be ready at http://localhost:8080/openmrs..."
MAX_WAIT=300 # 5 minutes
WAIT_TIME=0
while true; do
  STATUS=$(curl -sL -w "%{http_code}" -o /dev/null http://localhost:8080/openmrs)
  echo "OpenMRS status: $STATUS"
  if [[ "$STATUS" =~ ^(200|302|401)$ ]]; then
    echo "OpenMRS is up (Status: $STATUS)"
    break
  fi
  if [ "$WAIT_TIME" -ge "$MAX_WAIT" ]; then
    echo "Timeout waiting for OpenMRS. Proceeding anyway..."
    break
  fi
  echo "OpenMRS is not ready yet - sleeping..."
  sleep 10
  WAIT_TIME=$((WAIT_TIME + 10))
done

# Keep the container running by tailing the logs
echo "Tailing logs..."
tail -f /usr/local/tomcat/logs/catalina.out
