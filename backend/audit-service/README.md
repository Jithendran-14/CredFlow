# audit-service

Owner: Member 2. Port: 8086. Schema: CF_AUDIT.

Implemented: secured foundation endpoint `GET /api/v1/system/audit-service/info`, public health, JWT issuer/expiry/audience validation, Keycloak realm-role mapping, request correlation and structured logs. Flyway outbox/inbox tables and Oracle/JPA/Kafka wiring are included.

The starter consumes `application.submitted`, commits a safe audit record and inbox together, deduplicates event IDs, and sends exhausted consumption failures to a dead-letter topic. `GET /api/v1/applications/{id}/audit` is ADMIN-only. Additional events, pagination, replay controls and finer admin permissions remain to implement.

See the root README and `docs/development/ownership.md` for startup and assigned business work. Do not add successful placeholder business responses.
