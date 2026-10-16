-- Read-only reports. Connect as CF_SIM_BANK_A, then rerun as CF_SIM_NBFC_B.
-- Unqualified table names intentionally resolve only in the connected lender's own schema.
-- No H2, ALTER SESSION or other-schema joins.
-- :application_id is dashed UUID text or NULL; :lender_code is bank-a/nbfc-b or NULL.
SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS OWNING_SCHEMA FROM DUAL;

-- 1. Distinct lender cases with their own request reference and wire external ID.
SELECT c.CASE_KEY, c.LENDER_CODE, c.LENDER_ID,
       RAWTOHEX(c.SUBMISSION_ID) AS SUBMISSION_UUID_HEX,
       RAWTOHEX(c.APPLICATION_ID) AS APPLICATION_UUID_HEX,
       c.APPLICATION_REVISION, c.EXTERNAL_ID, c.STATUS, c.ACCEPTED_AT,
       c.REQUESTED_AMOUNT, c.OFFERED_AMOUNT, c.OFFER_FEES, c.OFFER_RATE,
       c.CALLBACK_SEQUENCE, c.ROW_VERSION
FROM CF_SIM_CASE c
WHERE (:application_id IS NULL OR c.APPLICATION_ID = HEXTORAW(REPLACE(:application_id, '-', '')))
  AND (:lender_code IS NULL OR c.LENDER_CODE = :lender_code)
ORDER BY c.LENDER_CODE, c.CASE_KEY;

-- 2. Callback delivery/retry evidence. IDs and payload hashes remain stable on retry.
SELECT RAWTOHEX(b.EVENT_ID) AS CALLBACK_UUID_HEX, b.CASE_KEY,
       b.LENDER_CODE, b.LENDER_ID, b.CALLBACK_SEQUENCE, b.STATUS,
       b.ATTEMPTS, b.NEXT_ATTEMPT_AT, b.FAILURE_CODE,
       JSON_VALUE(b.PAYLOAD_JSON, '$.correlationId' RETURNING VARCHAR2(100)) AS CORRELATION_ID,
       JSON_VALUE(b.PAYLOAD_JSON, '$.eventType' RETURNING VARCHAR2(100)) AS EVENT_TYPE
FROM CF_SIM_CALLBACK b
JOIN CF_SIM_CASE c ON c.CASE_KEY = b.CASE_KEY
WHERE (:application_id IS NULL OR c.APPLICATION_ID = HEXTORAW(REPLACE(:application_id, '-', '')))
  AND (:lender_code IS NULL OR b.LENDER_CODE = :lender_code)
ORDER BY b.CASE_KEY, b.CALLBACK_SEQUENCE;

-- 3. Failed callback replay candidates; replay with ops.replay, never direct SQL mutation.
SELECT RAWTOHEX(EVENT_ID) AS CALLBACK_UUID_HEX, CASE_KEY,
       LENDER_CODE, CALLBACK_SEQUENCE, ATTEMPTS, FAILURE_CODE
FROM CF_SIM_CALLBACK
WHERE STATUS = 'DEAD'
ORDER BY CASE_KEY, CALLBACK_SEQUENCE;

-- 4. Per-lender independence and repeatable fixture outcome totals.
SELECT LENDER_CODE, STATUS, COUNT(*) AS CASE_COUNT
FROM CF_SIM_CASE
GROUP BY LENDER_CODE, STATUS
ORDER BY LENDER_CODE, STATUS;

-- 5. Callback queue totals; SENT is final delivery acknowledgement, not a business decision.
SELECT LENDER_CODE, STATUS, COUNT(*) AS CALLBACK_COUNT,
       MIN(NEXT_ATTEMPT_AT) AS EARLIEST_ATTEMPT, MAX(ATTEMPTS) AS MAX_ATTEMPTS
FROM CF_SIM_CALLBACK
GROUP BY LENDER_CODE, STATUS
ORDER BY LENDER_CODE, STATUS;
