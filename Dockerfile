# Use Tomcat 9 with OpenJDK 11 as a base image for OpenMRS 2.8
FROM tomcat:9-jdk11

# Set environment variables for Tomcat/OpenMRS
ENV OPENMRS_HOME=/root/.OpenMRS

# Copy the OpenMRS .war file, configuration template, and init SQL
COPY openmrs.war /usr/local/tomcat/webapps/openmrs.war
COPY openmrs-runtime.properties.template /usr/local/tomcat/openmrs-runtime.properties.template
COPY openmrs_schema.sql /usr/local/tomcat/openmrs_schema.sql
COPY openmrs_seed.sql /usr/local/tomcat/openmrs_seed.sql
COPY entrypoint.sh /usr/local/tomcat/entrypoint.sh
COPY modules/ /usr/local/tomcat/modules/

# Install mysql-client and curl to run the init SQL and check health
RUN apt-get update && apt-get install -y default-mysql-client curl && rm -rf /var/lib/apt/lists/*

# Ensure the entrypoint script is executable
RUN chmod +x /usr/local/tomcat/entrypoint.sh

# Expose the default Tomcat port
EXPOSE 8080

# Start with the custom entrypoint
ENTRYPOINT ["/usr/local/tomcat/entrypoint.sh"]
