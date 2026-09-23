FROM eclipse-temurin:21-jdk AS build

WORKDIR /app

COPY .mvn .mvn
COPY mvnw pom.xml ./

RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

COPY src ./src

RUN ./mvnw clean package -DskipTests -B


FROM eclipse-temurin:21-jre

WORKDIR /app

RUN groupadd --system ekspersiz && \
    useradd --system --gid ekspersiz --home-dir /app --no-create-home ekspersiz && \
    mkdir -p /data/uploads && \
    chown -R ekspersiz:ekspersiz /app /data/uploads

COPY --from=build --chown=ekspersiz:ekspersiz /app/target/*.jar app.jar

USER ekspersiz

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]