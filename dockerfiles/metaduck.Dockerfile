# https://github.com/MotherDuck-Open-Source/metabase_duckdb_driver
FROM eclipse-temurin:21-jre

ENV MB_PLUGINS_DIR=/plugins
RUN mkdir -p ${MB_PLUGINS_DIR} /app

ADD https://downloads.metabase.com/latest/metabase.jar /app/metabase.jar
ADD https://github.com/MotherDuck-Open-Source/metabase_duckdb_driver/releases/latest/download/duckdb.metabase-driver.jar ${MB_PLUGINS_DIR}/

EXPOSE 3000
CMD ["java", "-jar", "/app/metabase.jar"]
