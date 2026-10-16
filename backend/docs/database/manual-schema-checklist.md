# Manual Oracle schema checklist

The user owns table creation/migrations. This checklist describes the current Member 3 entity mappings; it executes no DDL/DML and does not claim that an existing Oracle schema matches. Startup uses `spring.jpa.hibernate.ddl-auto=validate`. Check the actual environment with the supplied Oracle tests and metadata queries before starting the applications.

## Owners and type conventions

| Application / schema owner | Mapped tables | Sequence |
| --- | --- | --- |
| Orchestration / CF_ORCHESTRATION | CF_WORKFLOW, CF_SUBMISSION, CF_OFFER, CF_INFORMATION_REQUEST, CF_WORKFLOW_IDEMPOTENCY, CF_M3_DELIVERY | CF_M3_DELIVERY_SEQ |
| Integration / CF_LENDER_INTEGRATION | CF_INT_DISPATCH, CF_INT_TASK, CF_INT_CALLBACK, CF_M3_DELIVERY | CF_M3_DELIVERY_SEQ |
| Simulator Bank A / CF_SIM_BANK_A | CF_SIM_CASE, CF_SIM_CALLBACK | None: UUID/case key is generated in Java; callback sequence is held on the case row. |
| Simulator NBFC B / CF_SIM_NBFC_B | Same two simulator tables, physically owned by this separate user | None |

Each lender simulator runs independently with its own datasource/schema. It does not read the other bank's tables. Credentials are BANK_A_DB_USER/PASSWORD and NBFC_B_DB_USER/PASSWORD; ORACLE_URL identifies the database service. Do not grant these users access to another service's business tables. Member 1's marketplace and Member 2's verification modules are separate contributions outside these mapped lender tables.

Notation below: **U** = RAW(16) for UUID, **I** = NUMBER(10,0), **L** = NUMBER(19,0), **B** = NUMBER(1,0) constrained to 0/1, **T** = TIMESTAMP(6) WITH TIME ZONE for Instant/UTC, **V(n)** = VARCHAR2(n CHAR), **C** = CLOB. The shared configuration explicitly sets preferred UUID JDBC type BINARY and preferred boolean type NUMERIC. Confirm precision/timezone compatibility with the actual Hibernate/Oracle runtime. Unannotated String fields have JPA length 255. Fields marked PK are primary keys; explicit `nullable=false` fields are labelled NN. Business-required primitive/state fields should also have appropriate null/check constraints in your manual schema.

## Shared durable delivery table (Orchestration and Integration separately)

| CF_M3_DELIVERY column | Type / mapping |
| --- | --- |
| DELIVERY_ID | V(64), PK; KIND:UUID text, not RAW |
| KIND | V(12), NN |
| APPLICATION_ID | U, NN |
| TARGET_NAME | V(160), NN |
| PAYLOAD_JSON | C, NN |
| PAYLOAD_HASH | V(64), NN |
| POSITION_NO | L, NN; allocated from the owner's CF_M3_DELIVERY_SEQ |
| STATUS | V(12), NN |
| ATTEMPTS | I, NN |
| NEXT_ATTEMPT_AT | T, NN |
| LEASE_UNTIL | T |
| LEASE_TOKEN | U |
| CREATED_AT | T, NN |
| LAST_ERROR | V(120) |
| ROW_VERSION | L, JPA optimistic version |

Use a noncycling increasing sequence within each owner; it is used by Integration task ordering too. Suggested indexes cover (KIND, STATUS, NEXT_ATTEMPT_AT), (APPLICATION_ID, KIND, POSITION_NO) and lease/replay lookup. The simulator excludes platform delivery entities and disables the Kafka delivery engine, so it does not require this table/sequence.

## CF_ORCHESTRATION

| CF_WORKFLOW columns | Type / mapping |
| --- | --- |
| ID | U, PK |
| SELLER_SUBJECT | V(255), nullable legacy JWT subject |
| MARKETPLACE_SELLER_ID | V(120), nullable external marketplace reference |
| SELLER_ID | V(120), nullable trusted opaque seller ID; **changed from RAW(16)** |
| MARKETPLACE_ID | U |
| REVISION | I |
| AMOUNT | NUMBER(19,2), NN |
| CURRENCY, PURPOSE, LEGAL_NAME, STATUS, HEALTH, DETAIL, LENDER_ID, PRODUCT_ID | V(255) each |
| PROFILE_JSON, CONSENT_JSON, DECISION_JSON, ELIGIBILITY_JSON, ORIGIN_JSON | C each |
| HEALTH_ISSUES_JSON | C; **new** stable per-job/task issue/tombstone map |
| WORKFLOW_VERSION, LAST_INTEGRATION_VERSION | L each |
| CONSENT_ID | U |
| CONSENT_VERSION | I |
| CONSENT_GRANTED | B |
| VERIFICATION_ID, SNAPSHOT_ID, EVALUATION_ID, ELIGIBILITY_ID, SUBMISSION_ID, CANCELLATION_ID | U each; snapshot ID is initially absent until Eligibility responds |
| DISPATCH_AUTHORIZED, REVISION_PENDING | B each |
| EXPECTED_REVISION, LAST_REFRESH_REVISION | I each |
| REVISION_OPERATION | U |
| EVALUATION_AS_OF_DATE | DATE; UTC date captured once per evaluation attempt |
| AUTHORISED_RETRIEVAL_REFERENCE | V(255); private trusted Consent/Verification reference |
| ELIGIBILITY_OPERATION_ID | U; upstream 202 operation reference |
| ELIGIBILITY_STATUS_URL | V(255); validated relative Eligibility operation path |
| UPDATED_AT | T |
| ROW_VERSION | L, JPA version |

| CF_SUBMISSION columns | Type / mapping |
| --- | --- |
| ID | U, PK |
| APPLICATION_ID | U, **unique** (one selected lender submission per application) |
| LENDER_ID, PRODUCT_ID, STATUS, EXTERNAL_ID, CANCELLATION_ACKNOWLEDGEMENT | V(255) each; lender/product IDs are stored as UUID text here |
| REVISION | I |
| CREATED_AT | T |
| ROW_VERSION | L |

| CF_OFFER columns | Type / mapping |
| --- | --- |
| ID | U, PK |
| APPLICATION_ID, SUBMISSION_ID, ACCEPTANCE_ID | U each |
| AMOUNT, FEES | NUMBER(19,2), NN each |
| RATE | NUMBER(9,4), NN |
| CURRENCY, INTEREST_TYPE, FREQUENCY, TERMS_REFERENCE, STATUS, ACKNOWLEDGEMENT | V(255) each |
| TENURE | I |
| VERSION | L, public offer concurrency token |
| EXPIRES_AT, ACCEPTED_AT | T each |
| ROW_VERSION | L, separate JPA version |

| CF_INFORMATION_REQUEST columns | Type / mapping |
| --- | --- |
| ID | U, PK |
| APPLICATION_ID, SUBMISSION_ID | U each |
| STATUS, ACKNOWLEDGEMENT | V(255) each |
| QUESTIONS_JSON, ANSWERS_JSON, DOCUMENTS_JSON | C each |
| VERSION | L, public question concurrency token |
| CREATED_AT | T |
| ANSWERED_AT | T; **new**, server time when seller answers are recorded |
| ROW_VERSION | L |

| CF_WORKFLOW_IDEMPOTENCY columns | Type / mapping |
| --- | --- |
| ID | V(64), PK, hash of actor/operation/key |
| REQUEST_HASH | V(64), NN |
| RESPONSE_JSON | C |
| HTTP_STATUS | I |

Index application status/marketplace/updated time as needed for operations queries; index submission lender/created time, question application/status/created time and offer application/status/expiry. Enforce application/offer/question status enums from the status-transition document. Cancellation acknowledgement is a separate column; do not require a CANCELLED submission decision status.

## CF_LENDER_INTEGRATION

| CF_INT_DISPATCH columns | Type / mapping |
| --- | --- |
| SUBMISSION_ID | U, PK; stable external idempotency reference |
| APPLICATION_ID | U, NN |
| LENDER_ID | V(80), NN |
| APPLICATION_REVISION | I, NN |
| PAYLOAD_HASH | V(64), NN |
| REQUEST_JSON | C, NN; cancellation tombstones may carry a partial request until reconciled |
| EXTERNAL_ID | V(120) |
| STATUS | V(30), NN |
| CANCELLATION_REQUESTED, CANCELLATION_ACKNOWLEDGED | B each |
| CALLBACK_SEQUENCE, EVENT_VERSION | L each |
| SUBMITTED_AT, LEASE_UNTIL | T each |
| LEASE_TOKEN | U |
| ROW_VERSION | L |

| CF_INT_TASK columns | Type / mapping |
| --- | --- |
| TASK_ID | U, PK |
| SUBMISSION_ID | U, NN |
| OPERATION | V(30), NN |
| PAYLOAD_HASH | V(64), NN |
| PAYLOAD_JSON | C, NN |
| STATUS | V(12), NN |
| NEXT_ATTEMPT_AT | T, NN |
| ATTEMPTS | I |
| POSITION | L; allocated from CF_M3_DELIVERY_SEQ |
| LEASE_TOKEN | U |
| FAILURE_CODE | V(300) |
| ROW_VERSION | L |

| CF_INT_CALLBACK columns | Type / mapping |
| --- | --- |
| EVENT_ID | U, PK |
| SUBMISSION_ID | U, NN |
| LENDER_SEQUENCE | L, NN |
| PAYLOAD_HASH | V(64), NN |
| CALLBACK_JSON, ACTOR_JSON | C, NN each |
| CORRELATION_ID | V(100), NN |
| STATUS | V(12), NN |
| RECEIVED_AT, NEXT_ATTEMPT_AT | T, NN each |
| ATTEMPTS | I |
| FAILURE_CODE | V(300) |
| ROW_VERSION | L |

Enforce **UK_INT_CB_SEQUENCE (SUBMISSION_ID, LENDER_SEQUENCE)**. Index tasks on status/next attempt and submission/position; callbacks on status/next attempt and submission/sequence. No tables in this schema refer to an Orchestration or simulator schema through database foreign keys.

## CF_SIM_BANK_A and CF_SIM_NBFC_B (same definition in each owner)

| CF_SIM_CASE columns | Type / mapping |
| --- | --- |
| CASE_KEY | V(120), PK; lender-code plus stable submission reference |
| LENDER_CODE | V(20), NN |
| LENDER_ID | V(80), NN |
| SUBMISSION_ID | U, NN |
| APPLICATION_ID | U; nullable for cancellation tombstones |
| APPLICATION_REVISION | I; nullable for cancellation tombstones |
| EXTERNAL_ID | V(100); external string, not UUID |
| PAYLOAD_HASH | V(64) |
| STATUS | V(40), NN |
| ACCEPTED_AT | T |
| STATE_JSON | C; persisted request/commands/questions/decisions/offers/acceptance |
| CALLBACK_SEQUENCE | L, NN |
| REQUESTED_AMOUNT, OFFERED_AMOUNT, OFFER_FEES | NUMBER(19,2) each |
| OFFER_RATE | NUMBER(9,4) |
| ROW_VERSION | L |

The commandCorrelationId and commandCausationId Java members are transient; **do not create columns for them**. Their values are persisted inside immutable callback payloads where needed.

| CF_SIM_CALLBACK columns | Type / mapping |
| --- | --- |
| EVENT_ID | U, PK |
| CASE_KEY | V(120), NN |
| LENDER_CODE | V(20), NN |
| LENDER_ID | V(80), NN |
| CALLBACK_SEQUENCE | L, NN |
| PAYLOAD_JSON | C, NN |
| STATUS | V(16), NN |
| ATTEMPTS | I, NN |
| NEXT_ATTEMPT_AT | T, NN |
| LEASE_ID | U |
| FAILURE_CODE | V(80) |
| ROW_VERSION | L |

Enforce **UK_SIM_CALLBACK_SEQUENCE (CASE_KEY, CALLBACK_SEQUENCE)** in each owner. Index callback status/next attempt and case/sequence. CASE_KEY's primary key enforces reference idempotency within each lender's own schema; payload-hash conflicts return 409. Both lender users should have their own table/connection privileges only.

## Before marking database work verified

1. Create/update the four schema owners manually; provide their actual environment credentials and service URL. Preserve your existing data/migration history deliberately.
2. Compare USER_TAB_COLUMNS / USER_CONSTRAINTS / USER_INDEXES / USER_SEQUENCES with this checklist. All UUID columns must be RAW(16), not VARCHAR2(36); external IDs and hashed/string keys remain VARCHAR2.
3. Add the new workflow HEALTH_ISSUES_JSON and information ANSWERED_AT mappings before validate-mode startup. Validate all four applications; each simulator validates its own bank schema at startup.
4. Run the opt-in Oracle tests in isolated fixture IDs/schemas. Verify locking, rollback, uniqueness and startup validation against the actual server version. Offline configuration tests disable database access and cannot establish these facts.
5. Execute the read-only reports as each owning user. They contain no migrations, fixture mutations or cross-service joins; simulator reports intentionally use the current bank user's schema.
6. Capture the API journey, correlated logs and Member 2 Audit records after real Kafka/Keycloak/teammate services are available. SQL visibility is an operations capability, not an API ownership bypass.

## Member 1/2 contract alignment upgrade

The two new contracts use opaque sellerId strings such as SELLER-1001, not UUIDs.
Manually reconcile existing CF_WORKFLOW.SELLER_ID data to the Application owner's
trusted mapping before changing the column to VARCHAR2(120 CHAR). Do not hash,
truncate or reinterpret existing RAW bytes as a seller identity. Legacy subject
ownership remains available only when the stored trusted sellerId is absent.
Preserve history and decide the conversion with your real data before executing DDL.

Make SELLER_SUBJECT and MARKETPLACE_SELLER_ID nullable. Add EVALUATION_AS_OF_DATE,
AUTHORISED_RETRIEVAL_REFERENCE, ELIGIBILITY_OPERATION_ID and ELIGIBILITY_STATUS_URL
with the types above. No ALTER/CREATE statement or automatic backfill is supplied.
Raw application/submission/lender reference UUIDs keep their existing types.
Both bank schemas remain separate Oracle owners; the upstream H2 draft is not imported.