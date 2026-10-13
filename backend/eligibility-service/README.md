# eligibility-service

Owner: Member 2. Port: 8083. Schema: CF_ELIGIBILITY.

Implemented: secured foundation endpoint `GET /api/v1/system/eligibility-service/info`, public health, JWT issuer/expiry/audience validation, Keycloak realm-role mapping, request correlation and structured logs. Flyway outbox/inbox tables and Oracle/JPA/Kafka wiring are included.

See the root README and `docs/development/ownership.md` for startup and assigned business work. Do not add successful placeholder business responses.
