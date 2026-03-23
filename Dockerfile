# ========================================
# Stage 1: Build
# ========================================
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /workspace

COPY pom.xml ./pom.xml
RUN mvn -q -DskipTests dependency:go-offline

COPY src ./src
COPY agent ./agent
COPY build/native-config/config ./build/native-config/config

# Replace raw config source by generated final config before packaging
RUN rm -rf ./src/main/resources/config \
    && mkdir -p ./src/main/resources \
    && cp -r ./build/native-config/config ./src/main/resources/config

RUN mvn -q -DskipTests clean package

# ========================================
# Stage 2: Runtime
# ========================================
FROM eclipse-temurin:21-jre
WORKDIR /app

COPY --from=build /workspace/target/cloud-config-server-*.jar /app/app.jar
COPY --from=build /workspace/agent/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar

EXPOSE 8888

ENV JAVA_TOOL_OPTIONS=""

ENTRYPOINT ["sh", "-c", "java $JAVA_TOOL_OPTIONS -jar /app/app.jar"]