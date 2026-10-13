-- Execute as CF_APPLICATION. Do not join another service schema.
SELECT application_id, application_reference, marketplace_id, seller_id,
       requested_amount, status, application_revision, version, workflow_version
FROM loan_application ORDER BY created_at;

SELECT event_id, application_id, event_type, created_at, published_at, attempts
FROM event_outbox ORDER BY created_at;

SELECT caller_subject, idempotency_key, application_id
FROM api_idempotency ORDER BY caller_subject, idempotency_key;
