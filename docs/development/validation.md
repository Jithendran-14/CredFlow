# Starter validation

Validated on 13 October 2026 using the committed Maven wrapper, Maven 3.9.16 and local Oracle JDK 25 with Java release target 21. CI is configured for Temurin JDK 21; a GitHub CI result is separate evidence from this local run.

`mvnw.cmd -B -ntp verify` succeeded for the entire reactor and packaged all eight executable applications. The suite contains 65 passing tests across audience checks, infrastructure configuration, gateway security/forwarding, each service foundation, application submission and Audit.

Checks cover unauthenticated API rejection, admin restrictions, correlation headers, specific gateway routes before the Application fallback, bearer forwarding, marketplace ownership, seller access, required input, same-key replay, different-payload conflicts, active-application prevention, concurrent duplicates, transaction rollback, Audit deduplication and safe-field filtering.

All YAML/JSON configuration parses. PowerShell helpers parse and generated/imported 19 local credential variables without printing their values. `.env` is ignored by Git. Bash setup/topic/health scripts pass syntax checks and have LF line endings.

The packaged external simulator was started as a local Java process: health returned UP and its protected API returned 401 without a token. The process was stopped after the check.

Docker was unavailable. Oracle migrations/locking, live Kafka outbox/Audit delivery, Keycloak realm import/token issuance and full Compose startup remain unverified. H2 transaction tests do not establish Oracle or PL/SQL compatibility. Follow the live acceptance checklist in runbook.md before declaring the shared infrastructure ready.

## Local Oracle verification on 14 October 2026

The existing native Oracle installation at localhost:1521/FREEPDB1 was verified without Docker. The local setup created all six CF service users and connection checks succeeded for each using its own credential. Application Service then started against Oracle, successfully applied Flyway V1 and V2, and returned health UP. The Docker-free seed script created four synthetic seller records. The temporary Java process was stopped after verification.

Application Service used an isolated test port, 18081, and `credflow.outbox.enabled=false` for this database check. Normal STS runs use 8081. Kafka, Keycloak, Audit migration/consumption, and the other services' live migrations were not verified by this check; neither was the application's outbox locking query. The financial package remains to implement. See sts-local-oracle.md for local setup instructions.
