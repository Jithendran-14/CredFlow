# CredFlow development starter

CredFlow coordinates fictional seller loan applications between a marketplace and lenders. This repository is the shared starting point for a three-person training project. The first delivery target is a complete Bank A journey by Day 6.

## What works in this starter

- Eight Spring Boot application entry points and one nondeployable technical support library.
- JWT issuer, time and audience validation, Keycloak realm roles, protected endpoints and request correlation.
- Application creation and owner-restricted reads, input validation, caller organisation checks, idempotency and one active application per seller/marketplace.
- Application and pending event commit atomically. An Oracle outbox publisher sends `application.submitted` to Kafka, using application ID as the key and preserving event ID on retry.
- Audit consumes that event, stores approved fields and records its inbox in the same transaction. Duplicate events are ignored and failed consumption uses bounded retries plus a dead-letter topic.
- Oracle service migrations, infrastructure Compose, Keycloak realm, nine human accounts, distinct machine clients, fixture data and a GitHub Actions build.

Consent processing, verification calls, financial aggregation, eligibility rules, workflow progression, lender adapters, offers, corrections and the frontend remain to implement. The other services expose authenticated foundation endpoints; they do not return fake business successes. The current submitted application remains `AWAITING_CONSENT`.

## Prerequisites

Install a JDK 21 or newer supported by this Boot version, Docker Desktop with Linux containers and Compose v2, and Git. The Maven wrapper downloads Maven 3.9.16. Allow sufficient memory for Oracle, Keycloak, Kafka and the Java services; begin with the infrastructure and your assigned services if resources are limited.

Oracle Container Registry may require sign-in and acceptance of its image terms. Use the documented `database/free:23.26.0.0-lite` image; do not silently substitute H2 for the six business databases.

## Quick start on Windows

For STS without Docker and an existing Oracle database, follow [the local Oracle setup guide](docs/development/sts-local-oracle.md). It includes schema setup, connection verification and a Docker-free seed script.

Then follow [local Keycloak and Insomnia tests](docs/development/keycloak-insomnia-local.md) to obtain a real marketplace token and exercise application submission, replay and reads.

From the repository root in PowerShell:

```powershell
git clone https://github.com/Jithendran-14/CredFlow.git
cd CredFlow
.\scripts\New-LocalEnvironment.ps1
.\mvnw.cmd -B -ntp verify
docker compose --env-file .env -f infrastructure/compose.yml up -d
docker compose --env-file .env -f infrastructure/compose.yml ps
```

Wait for Oracle, Kafka and Keycloak to become healthy and for `kafka-init` to finish successfully. First Oracle startup can take several minutes.

To start all eight applications from the built JARs:

```powershell
docker compose --env-file .env -f infrastructure/compose.yml --profile apps up -d --build
docker compose --env-file .env -f infrastructure/compose.yml --profile apps ps
.\scripts\Seed-Demo.ps1
.\scripts\Smoke-Submission.ps1
```

Wait for Application Service health before seeding. Check `http://localhost:8081/actuator/health` and `http://localhost:8080/actuator/health`. The smoke script authenticates the marketplace, creates the application twice with the same key, and checks that the same ID is returned.

For STS/local Java development, leave infrastructure in Docker, import the root as Existing Maven Projects, set the JDK to 21, and import the variables from `.env` into each launch configuration. In PowerShell, `. .\scripts\Import-LocalEnvironment.ps1` loads them for that terminal. Run the corresponding main class, or:

```powershell
. .\scripts\Import-LocalEnvironment.ps1
java -jar backend/application-service/target/application-service-0.1.0-SNAPSHOT.jar
```

Do not run a local service on a port already occupied by its application container. Stop that container first. Each developer needs a locally generated `.env`; do not share or commit credentials.

On Linux/macOS, use `./mvnw` and the same Compose commands. Copy `.env.example` to `.env` and replace every `__GENERATE__` with a different strong alphanumeric/underscore value. The helper scripts are PowerShell scripts and also work with PowerShell 7 on these platforms.

## Ports and ownership

| Application | Port | Owner | Oracle schema |
|---|---:|---|---|
| API Gateway | 8080 | Member 1 | None |
| Application | 8081 | Member 1 | CF_APPLICATION |
| Consent and Verification | 8082 | Member 1 | CF_CONSENT |
| Eligibility | 8083 | Member 2 | CF_ELIGIBILITY |
| Orchestration | 8084 | Member 3 | CF_ORCHESTRATION |
| Lender Integration | 8085 | Member 3 | CF_LENDER_INTEGRATION |
| Audit | 8086 | Member 2 | CF_AUDIT |
| External simulator | 8090 | All three | H2 schemas/fixtures |
| Keycloak | 8180 | Member 1 | Container-managed development store |
| Kafka | 9092 | Member 2 | None |
| Oracle listener | 1521 | Member 2 | FREEPDB1 |

Infrastructure uses loopback-bound development ports. It is a local training configuration with HTTP and plaintext Kafka. Human API login uses Authorization Code with PKCE through `credflow-postman` (callback `http://localhost:7777/callback`) or the future `credflow-ui` client. Password grants are disabled. Seed usernames are `seller104` to `seller107`, `marketplace1`, `marketplace2`, `banka-officer`, `nbfcb-officer` and `credflow-admin`. Their password is your local `DEMO_USER_PASSWORD`.

## Working together

Pull `main`, create a feature branch, work within your assigned modules and submit a pull request. Run `mvnw verify` before review. Agree on contract changes before dependent implementations. Do not read another service schema, share JPA entities, or add business logic to `platform-support`.

Read [developer ownership](docs/development/ownership.md), [implementation status](docs/development/implementation-status.md), [architecture](docs/architecture/overview.md), [decision log](docs/requirements/decision-log.md), [security matrix](docs/security/access-matrix.md), and [local troubleshooting](docs/development/runbook.md). Implemented APIs are in `contracts/openapi`; the next-flow contract blueprint is in `contracts/day6-flow.md`.

## Validation limits

The starter's automated suite uses H2 in Oracle compatibility mode to check Java transactions, validation and authorisation without Docker. This is not evidence of Oracle SQL/PLSQL compatibility. Container startup, real Keycloak token issuance, the Kafka relay and Oracle migrations require the Docker smoke checks in the runbook. SQL and PL/SQL acceptance tests must run against Oracle before the Day 6 milestone.

On 14 October 2026, native Oracle connections for all six service users and Application Service's two migrations were verified against local FREEPDB1 without Docker. Its health check and local seller seeding succeeded. Kafka/Keycloak integration and the remaining services' live database migrations still need verification; see [the validation record](docs/development/validation.md).
