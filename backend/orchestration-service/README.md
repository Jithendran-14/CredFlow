# orchestration-service

Owner: Member 3. Port: 8084. Schema: CF_ORCHESTRATION.

Implemented: secured foundation endpoint `GET /api/v1/system/orchestration-service/info`, public health, JWT issuer/expiry/audience validation, Keycloak realm-role mapping, request correlation and structured logs. Flyway outbox/inbox tables and Oracle/JPA/Kafka wiring are included.

See the root README and `docs/development/ownership.md` for startup and assigned business work. Do not add successful placeholder business responses.
