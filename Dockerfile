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
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]