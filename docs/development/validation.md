# Starter validation

Validated on 13 October 2026 using the committed Maven wrapper, Maven 3.9.16 and local Oracle JDK 25 with Java release target 21. CI is configured for Temurin JDK 21; a GitHub CI result is separate evidence from this local run.

`mvnw.cmd -B -ntp verify` succeeded for the entire reactor and packaged all eight executable applications. The suite contains 65 passing tests across audience checks, infrastructure configuration, gateway security/forwarding, each service foundation, application submission and Audit.

Checks cover unauthenticated API rejection, admin restrictions, correlation headers, specific gateway routes before the Application fallback, bearer forwarding, marketplace ownership, seller access, required input, same-key replay, different-payload conflicts, active-application prevention, concurrent duplicates, transaction rollback, Audit deduplication and safe-field filtering.

All YAML/JSON configuration parses. PowerShell helpers parse and generated/imported 19 local credential variables without printing their values. `.env` is ignored by Git. Bash setup/topic/health scripts pass syntax checks and have LF line endings.

The packaged external simulator was started as a local Java process: health returned UP and its protected API returned 401 without a token. The process was stopped after the check.

Docker was unavailable. Oracle migrations/locking, live Kafka outbox/Audit delivery, Keycloak realm import/token issuance and full Compose startup remain unverified. H2 transaction tests do not establish Oracle or PL/SQL compatibility. Follow the live acceptance checklist in runbook.md before declaring the shared infrastructure ready.
