# lender-integration-service

Owner: Member 3. Port: 8085. Schema: CF_LENDER_INTEGRATION.

Implemented: secured foundation endpoint `GET /api/v1/system/lender-integration-service/info`, public health, JWT issuer/expiry/audience validation, Keycloak realm-role mapping, request correlation and structured logs. Flyway outbox/inbox tables and Oracle/JPA/Kafka wiring are included.

See the root README and `docs/development/ownership.md` for startup and assigned business work. Do not add successful placeholder business responses.
