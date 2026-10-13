# mock-external-systems

Owner: Members 1–3. Port: 8090. Separate in-memory H2 schemas for simulator modules.

Implemented: secured foundation endpoint `GET /api/v1/system/mock-external-systems/info`, public health, JWT issuer/expiry/audience validation, Keycloak realm-role mapping, request correlation and structured logs. Marketplace, verification and lender behaviour remains to implement.

See the root README and `docs/development/ownership.md` for startup and assigned business work. Do not add successful placeholder business responses.
