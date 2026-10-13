FROM eclipse-temurin:21-jre
ARG MODULE
WORKDIR /app
COPY ${MODULE}/target/*-SNAPSHOT.jar /app/service.jar
USER 10001
ENTRYPOINT ["java", "-jar", "/app/service.jar"]
