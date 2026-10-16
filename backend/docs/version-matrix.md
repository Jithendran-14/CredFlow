# Dependency and environment versions

Versions below distinguish what this Member 3 build resolves from infrastructure
that teammates still need to confirm. Unavailable infrastructure versions are not
invented or described as an approved team combination.

| Component | Member 3 configuration or observed resolution | Validation scope |
| --- | --- | --- |
| Java compiler target | 21 | Maven release setting |
| JDK used for verification | 25.0.4.1 | Local build/test JVM |
| Maven used for verification | 3.9.16 | Installed Maven |
| Spring Boot | 3.5.6 | Parent POM |
| Spring Security | 6.5.5 | Resolved Boot dependency |
| Hibernate ORM | 6.6.29.Final | Resolved Boot dependency |
| Jackson Databind | 2.19.2 | Resolved Boot dependency |
| Oracle JDBC ojdbc11 | 23.7.0.25.01 | Resolved runtime dependency |
| Kafka client | 3.9.1 | Resolved Boot dependency |
| Oracle Database | Plan targets 26ai | Actual server version/live connectivity require team verification |
| Kafka broker | Member 2 supplies | Confirm deployed version, topics, partitions and ACLs |
| Auth | Member 1 custom RS256, port8085; version not supplied | Configure issuer/audience/public RSA key or JWKS and flat claims; narrow machine grants pending. Optional explicit Keycloak mode supports legacy claims. |
| Spring Cloud/Gateway | Member 1 supplies | Use their Boot-compatible Gateway release and method/path routing |
| Frontend | Excluded | No React/Vite application added |
| PowerShell helper scripts | PowerShell7; contract validation uses Test-Json | No Python/Node packages required |

Keep these concrete values with final test logs. The parent controls service
versions; do not add standalone Boot parents to individual modules. Complete the
shared infrastructure rows with teammates before recording the final team matrix.
The artifact's verification report records the latest actual test counts.
