# CredFlow Member 3 backend

Four independent Spring Boot applications with Oracle persistence and packages
organised by responsibility. The source retains the supplied Member1/Member2 API
and event contracts. Their pending service endpoints, publishers and machine grants
remain external integration work. No frontend is included.

| Application | Port | Oracle owner | Main class |
| --- | --- | --- | --- |
| Orchestration | 8084 | CF_ORCHESTRATION | com.credflow.OrchestrationServiceApplication |
| Lender Integration | 8087 | CF_LENDER_INTEGRATION | com.credflow.LenderIntegrationServiceApplication |
| Mock Bank A | 8091 | CF_SIM_BANK_A | com.credflow.MockBankAApplication |
| Mock NBFC B | 8092 | CF_SIM_NBFC_B | com.credflow.MockNbfcBApplication |

## Java package layout in every application

```text
src/main/java/com/credflow/
  <Application>.java
  api/           HTTP mapping and parameter interfaces
  controller/    REST implementations that delegate to services
  service/       Business rules and transaction coordination
  dto/           API requests responses and internal delivery data
  entity/        JPA entities with private fields and accessors
  repository/    Own-schema JPA queries persistence and locking
  scheduler/     Local background task entrypoints
```

All seven packages contain the owning application's actual Java files. Bank A and
NBFC B each contain their own simulator service, repository, entities and receipt
DTO. They can be developed or deployed separately. The common infrastructure library
remains under `com.credflow.platform`; its delivery entity is under
`com.credflow.platform.entity` and is scanned only by Orchestration and Integration.

`api` holds annotated interfaces, while `controller` implements them. The interfaces
preserve existing HTTP paths, validation annotations and status codes. The entity
fields remain the JPA mapping source; private fields and accessors do not require
new columns or tables. Entity names and SQL definitions stay stable.

## Project layout and builds

```text
backend/pom.xml                       Maven aggregator
backend/member3-common/               Non-executable infrastructure library
backend/orchestration-service/        Independent application
backend/lender-integration-service/   Independent application
mocks/mock-bank-a/                   Independent application with all own layers
mocks/mock-nbfc-b/                   Independent application with all own layers
config/                              Separate environment templates
contracts/openapi/                   Four service contracts and combined reference
contracts/upstream/                  Original Member1 and Member2 documents unchanged
database/                            Manual Oracle setup and verification SQL
scripts/                             Environment loaders launchers and checks
```

Import the nested `backend/pom.xml` as the Maven parent in your IDE. Use Java21 or
later and Maven3.9. From the nested Maven folder:

```powershell
mvn clean verify
```

Build just one application and its common library with the corresponding command:

```powershell
mvn -pl orchestration-service -am package
mvn -pl lender-integration-service -am package
mvn -pl ../mocks/mock-bank-a -am package
mvn -pl ../mocks/mock-nbfc-b -am package
```

These are alternative builds. No application depends on a peer application's JAR.
Each executable packages its own code and required infrastructure library.

## Configure and start

Extract this version into a fresh folder. Do not mix classes from earlier releases.
Copy `.env.example` to `.env` for local team assembly, or copy the matching template
from `config/*.env.example` for an isolated deployment. Enter actual values before
loading them. Java does not automatically read a .env file.

Each service needs its own Oracle user/password and the actual Auth issuer, audience,
and exactly one of JWT_JWKS_URI or JWT_PUBLIC_KEY_LOCATION (a public RSA PEM resource).
Default JWT_ROLE_MODE=FLAT reads the configured JWT_ROLE_CLAIM, normally roles, and
the agreed camelCase identity claims. KEYCLOAK mode is optional and explicit.
Never put a private key or SYSTEM credentials into application configuration.

Member1 must provision the scoped machine grant endpoint and the required client
identities/secrets. Until they are supplied, leave OAUTH_TOKEN_URL/client secrets
blank; protected outbound work fails clearly with SERVICE_AUTHENTICATION_NOT_CONFIGURED.
Do not replace service credentials with an ADMIN or seller login token.

From the outer project root, use four separate terminals:

```powershell
.\scripts\Start-Member3Service.ps1 -Service bank-a
.\scripts\Start-Member3Service.ps1 -Service nbfc-b
.\scripts\Start-Member3Service.ps1 -Service integration
.\scripts\Start-Member3Service.ps1 -Service orchestration
```

For a service-specific environment file:

```powershell
.\scripts\Start-Member3Service.ps1 -Service bank-a -EnvFile .\config\bank-a.env
```

The launcher uses an existing process environment if no file exists. Direct executable
JAR commands from the nested Maven folder are:

```powershell
java -jar .\orchestration-service\target\orchestration-service-1.0.0.jar
java -jar .\lender-integration-service\target\lender-integration-service-1.0.0.jar
java -jar ..\mocks\mock-bank-a\target\mock-bank-a-1.0.0.jar
java -jar ..\mocks\mock-nbfc-b\target\mock-nbfc-b-1.0.0.jar
```

Integration uses BANK_A_URL and NBFC_B_URL independently. Auth stays on the upstream
8085 and the upstream shared provider mock stays on8090. This release does not
implement the teammate identity/financial-provider modules or their source databases.

## Oracle setup

The default URL is jdbc:oracle:thin:@//localhost:1521/FREEPDB1. Substitute your actual
application PDB service. Four separate owners are used. Each bank may override
BANK_A_ORACLE_URL or NBFC_B_ORACLE_URL independently and needs only its own credentials.

For a fresh installation, connect as SYSTEM to the correct PDB and run the scripts
under `database/`. Existing matching schemas do not need to be dropped or recreated.
Keep spring.jpa.hibernate.ddl-auto=validate and Flyway disabled. No H2 is used.
The package refactor preserves the 14 physical tables and two sequences.

## API contracts and verification

Import orchestration.yaml, lender-integration.yaml, mock-bank-a.yaml and
mock-nbfc-b.yaml from contracts/openapi/. mock-lenders.yaml is a combined reference
with per-path server addresses. The API interfaces in source are the HTTP mapping
contracts; the OpenAPI files describe their complete external schemas.

Public seller workflow/offer/information routes go to Orchestration. Lender officer
commands go to Integration. Internal, callback, simulator and operational replay
routes remain private and require their configured machine identities/scopes.
The Member1 Gateway deployment and browser login flow must follow the actual Auth
contract. CORS is configurable for later browser integration; no frontend is added.

Run source and contract checks from the outer project root:

```powershell
.\scripts\Test-ServiceBoundaries.ps1
.\scripts\Test-Contracts.ps1
```

Default Maven tests use offline contexts and mocked DB/network boundaries. They
cover API-interface route discovery, entity scan isolation, private mapped fields,
workflow behavior, both lender implementations, callbacks and security boundaries.
For live Oracle verification, configure the target test database and run the
documented opt-in `mvn -Poracle-it verify` from the nested Maven folder. This profile
does not create tables. It is separate from the default offline tests.

Read docs/team-contract-alignment.md and docs/acceptance-checklist.md before declaring
the full team journey complete. The actual Auth settings/machine grants, Application
publisher/enrichment, Consent authority/retrieval, Eligibility endpoints/publisher,
Kafka/Gateway and Audit integration still require joint live verification.

Once a real application is routed, scripts/Invoke-Member3Demo.ps1 can exercise either
lender with configured seller and officer tokens. It calls Member3 APIs and does not
invent missing upstream services. Demo fixtures are fictional and imported by their
owning teammate modules.
