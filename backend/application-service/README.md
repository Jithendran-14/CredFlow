# application-service

Owner: Member 1. Port: 8081. Schema: CF_APPLICATION.

Implemented: secured foundation endpoint `GET /api/v1/system/application-service/info`, public health, JWT issuer/expiry/audience validation, Keycloak realm-role mapping, request correlation and structured logs. Flyway outbox/inbox tables and Oracle/JPA/Kafka wiring are included.

The initial business slice implements `POST /api/v1/applications` and `GET /api/v1/applications/{id}` using service-owned JDBC tables. Creation enforces the marketplace organisation and registered seller relationship, required evidence fields, idempotency, and one active application. An outbox event commits with the application and is relayed to Kafka. Independent marketplace evidence verification, listing, internal access checks, corrections and status projection remain to implement.

See the root README and `docs/development/ownership.md` for startup and assigned business work. Do not add successful placeholder business responses.
