# Member 3 application structure

Every application has its own `com.credflow.api`, `controller`, `service`, `dto`,
`entity`, `repository` and `scheduler` packages. The main class is under
`com.credflow`, allowing Spring to discover the owning application's components.
Entity scanning is explicit: each app loads `com.credflow.entity`; only Orchestration
and Integration additionally load the common durable delivery entity package.

| Application | Controller | Service | Repository |
| --- | --- | --- | --- |
| Orchestration | WorkflowController | WorkflowService | WorkflowRepository |
| Integration | LenderIntegrationController | LenderIntegrationService | IntegrationRepository |
| Bank A | BankAController | BankASimulatorService | BankASimulatorRepository |
| NBFC B | NbfcBController | NbfcBSimulatorService | NbfcBSimulatorRepository |

`api` declares the HTTP mapping, parameters and validation. `controller` implements
the interfaces and delegates work. DTOs carry API values. Services coordinate
business rules and transactions. Repositories own JPA queries and pessimistic locks.
Entities have private fields, public accessors and public no-argument constructors;
JPA annotations remain on their fields. Schedulers trigger the owning service's work.

Each lender now owns all its simulation code inside its application source tree.
There is no separate simulation library. The sole shared library is member3-common,
which contains infrastructure under `com.credflow.platform`. It is not executable and
does not provide another application's business entities or datasource credentials.

Four executable JARs and four Oracle users remain separate. BANK_A_URL defaults to
8091 and NBFC_B_URL to8092. The upstream provider mock on8090 remains external. The
same package names across applications do not combine them: peer application JARs
must never be added to one another's runtime classpath. Maven reactor aggregation
only builds modules; it does not create a shared application process.

Existing HTTP paths, callback identities, event schemas, transaction semantics and
Oracle tables are retained. Spring route discovery and entity scan tests verify
the package boundaries in offline application contexts. Live Oracle/Kafka/Auth and
teammate journeys still need the configured target environment.
