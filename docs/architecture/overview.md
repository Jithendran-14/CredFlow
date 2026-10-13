# CredFlow architecture

Eight deployable Spring Boot applications share a repository. Six business services own six Oracle schemas. `platform-support` is a library, not a ninth application; it contains no database entities or business rules.

Gateway validates and forwards bearer tokens. Each service independently validates issuer, timestamp and audience. Application owns registered sellers and their user/organisation relationships. Other services must obtain protected ownership decisions through its internal API before exposing business resources; those endpoints remain to implement. Gateway never routes `/internal/**`.

Application owns decision-input revision and the seller-facing status projection. Orchestration will own progression after submission, expected result IDs, routing, offer actions and workflow version. Consent owns consent records. Eligibility owns financial snapshots and preliminary product results. Integration owns external lender mappings. Audit consumes approved business events.

Business updates and pending events commit together. Consumers commit inbox entries with their local business changes. Delivery is at least once; a crash after Kafka acknowledgement and before an outbox commit can cause redelivery, preserving event ID. Kafka partition key is application ID. Ordering across topics must be handled by state and identifier guards.

The starter relay deliberately uses an Oracle-specific row-lock query and has bounded attempts. Events exhausted after five attempts remain unpublished for operator attention. Audit consumption retries three times and publishes to `application.submitted.DLT`. Do not replay blindly; preserve original event IDs after fixing the cause.

There are no cross-schema joins, cross-schema foreign keys, shared JPA entities, Eureka, automatic lender fallback or parallel lender submissions. The simulator uses H2/JSON fixtures; business SQL/PLSQL belongs in Oracle.
