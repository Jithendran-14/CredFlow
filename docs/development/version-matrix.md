# Dependency version matrix

| Component | Pinned version | Location |
|---|---|---|
| Java language target | 21 | Root POM and CI |
| Spring Boot | 3.5.16 | Root parent |
| Spring Cloud | 2025.0.3 | Root imported BOM |
| Maven | 3.9.16 | Maven wrapper |
| Oracle Free 26ai image | 23.26.0.0-lite | Compose |
| Keycloak | 26.8.0 | Compose |
| Kafka broker | 4.0.0 | Compose |
| Oracle JDBC, Flyway, JUnit, Hibernate, Spring Kafka | Boot dependency-management versions | Effective POM |
| React | Not selected; frontend deferred | None |

Boot 3.5 is used to keep the training code on its established Spring generation. Cloud's documented compatibility maps 2025.0.x to Boot 3.5.x; that Cloud train is marked end-of-life, so this is a training baseline rather than a production support commitment. Do not upgrade one member's modules independently. Review a supported-generation upgrade separately if deployment becomes a goal.

Sources: [Spring Boot requirements](https://docs.spring.io/spring-boot/3.5/system-requirements.html), [Spring Cloud compatibility](https://spring.io/projects/spring-cloud/), [Cloud release notes](https://github.com/spring-cloud/spring-cloud-release/wiki/Spring-Cloud-2025.0-Release-Notes), [Keycloak Docker guide](https://www.keycloak.org/getting-started/getting-started-docker), [Kafka Docker guide](https://kafka.apache.org/40/getting-started/docker/), [Oracle 26ai Free image reference](https://docs.oracle.com/en/database/oracle/property-graph/26.2/spgdg/running-oracle-graph-quickstart-container-image.html), [Keycloak realm import](https://www.keycloak.org/server/importExport).

Local Java build/tests are recorded in validation.md. Containers need live verification; version pinning alone does not establish runtime compatibility.
