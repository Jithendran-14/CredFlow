# Local development runbook

## Startup

Generate `.env`, run `mvnw verify`, and start infrastructure using the root README commands. Read `docker compose --env-file .env -f infrastructure/compose.yml logs oracle kafka kafka-init keycloak` if readiness fails. Oracle setup scripts execute on first database creation; later restarts retain users and data. Changing `.env` does not rotate existing database/realm credentials.

Start only Application, Audit and Gateway for the implemented slice, or start the full apps profile:

```powershell
docker compose --env-file .env -f infrastructure/compose.yml --profile apps up -d --build application-service audit-service api-gateway
.\scripts\Seed-Demo.ps1
.\scripts\Smoke-Submission.ps1
```

Verify the outbox and audit using SQL through each owning schema:

```sql
-- CF_APPLICATION
SELECT application_id,status,application_revision FROM loan_application;
SELECT event_id,event_type,published_at,attempts FROM event_outbox;
-- CF_AUDIT
SELECT event_id,application_id,event_type,correlation_id FROM audit_event;
SELECT event_id FROM event_inbox;
```

The smoke is successful when one application exists, one stable outbox event is published, and Audit records that event once. Its application status remains AWAITING_CONSENT until the workflow is implemented. The script automatically checks creation/idempotency; the SQL queries verify Kafka/Audit completion.

## Troubleshooting

- Missing password variable: generate `.env`, then import it into your terminal or STS launch. Compose automatically receives it only with the shown `--env-file` argument.
- 401: verify issuer `http://localhost:8180/realms/credflow`, audience `credflow-api`, token expiry and signing keys. Container services fetch keys via the internal Keycloak URL but validate the external issuer.
- 403 on submission: use the marketplace machine client or an operations user whose organisation claim matches the request. A seller cannot invoke this endpoint directly.
- 404 for a known application: verify seller/marketplace ownership. The service hides inaccessible resources consistently.
- Oracle authentication failure: check that setup completed; inspect setup logs. Preserved database users retain original passwords.
- Topic errors: ensure `kafka-init` exited successfully. Host processes use localhost:9092; containers use kafka:19092.
- An event has attempts=5 and no published timestamp: fix the broker/cause, then a service owner may reset attempts for that specific event. Preserve its event_id; keep an operator record. A replay API remains to build.
- Audit DLT contains an event: fix schema/data handling, then replay under authorised operator control with the original event ID. Automated replay is not provided yet.
- Another application is active: same idempotency key repeats the original request. For a fresh scenario, use another seeded seller, or reset fixtures through a deliberate service-owned procedure. Do not alter history during normal demonstrations.

Stop containers with `docker compose --env-file .env -f infrastructure/compose.yml --profile apps stop`. Do not remove persistent volumes as routine startup/troubleshooting; doing so destroys demo state and identity configuration.

## Required live acceptance before Day 6

1. Start containers on Docker Desktop and inspect health/readiness.
2. Authenticate a real Keycloak marketplace client; confirm audience and organisation claims.
3. Submit/replay the request through Gateway and confirm ownership restrictions with seller accounts.
4. Query each schema for one application, published outbox event and one Audit/inbox record.
5. Stop Kafka temporarily; prove application creation remains durable, resumes publication and does not create duplicate audit rows.
6. Run Oracle-backed package and transaction checks after Eligibility implements the package.

Docker was unavailable on the starter author's machine; these live checks have not been represented as completed.

For the later native Oracle verification and Docker-free setup, see [STS local Oracle](sts-local-oracle.md) and [validation](validation.md). That check covers service-user connectivity and Application migrations, health and seeding; it does not complete the full infrastructure acceptance checklist above.
