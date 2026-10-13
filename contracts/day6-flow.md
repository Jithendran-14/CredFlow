# Day 6 flow contract blueprint

Only Application create/read and submitted-event Audit are implemented. The payloads below are the starting interface agreement for the remaining services; owners must complete OpenAPI/JSON Schema validation and review them together before feature coding. Do not treat this blueprint as a working endpoint inventory.

All IDs are UUID strings, money is two-decimal strings, timestamps are UTC, public paths start `/api/v1`. All events use the envelope in `events/event-envelope.schema.json`, include trusted actor provenance, and use applicationId as Kafka key. A synchronous error has code, message, correlationId and fieldErrors. Every asynchronous mutation returns `202 {operationId,status:"PENDING",statusUrl}`; `GET /api/v1/operations/{operationId}` enforces the original resource's permissions.

| Step | Interface | Minimum command/result data | Owner |
|---|---|---|---|
| Submission | POST /api/v1/applications; application.submitted | Implemented request/response and event schema | M1 |
| Workflow receipt | Consume application.submitted | Create authoritative workflow row and durable inbox; expected applicationRevision=1; emit versioned application.status.changed | M3 |
| Ownership | Protected internal Application lookup | Application ID plus trusted originating subject, roles and organisation; return allowed action/relationship; whitelist calling clients | M1 |
| Consent | POST /api/v1/applications/{id}/consents; consent.updated | scopes, sourceMarketplaceIds, recipientLenderIds, purpose, noticeVersion, expected version; consentId, consentVersion, status, validityPolicy | M1 |
| Verification | Protected internal command; verification.completed | applicationId, applicationRevision, consentId/version, verification request identity; result verificationId,status,checkedAt,reasonCode | M1 |
| Marketplace retrieval | Simulator protected marketplace API | Registered seller reference, authorised scope, reporting dates; complete coverage metadata and monthly records | M1 |
| Financial evaluation | Protected Eligibility command; eligibility.completed | applicationId, applicationRevision, verificationId,evaluationRequestId,asOfDate,authorised retrieval reference; immutable snapshotId and per-product results | M2 |
| Lender dispatch | Protected Integration command | submissionId, applicationId/revision, lenderId, productId,eligibilityResultId,snapshotId,consentId/version,current dispatch authorisation, canonical input | M3 |
| Lender response | Matching lender callback | Stable submissionId, lenderApplicationId,decisionId,decision,reason; separately complete offer terms | M3 |
| Offer presentation | GET /api/v1/applications/{id}/offers | offerId,submissionId,amount,currency,rate/type,tenure,repaymentFrequency,fees,termsReference,expiresAt,status,version | M3 |
| Acceptance | POST /api/v1/offers/{id}/acceptance | Idempotency-Key,expectedOfferVersion; atomic current-state/consent/UTC-expiry guard; locally recorded result plus lenderAcknowledgementStatus | M3 |

Orchestration serializes effective consent changes, dispatch authorisation, corrections and offer acceptance. Network dispatch is not a distributed transaction; authorised/in-flight requests may already have shared data and must be reconciled/cancelled. Do not advance merely because a command was queued.

Add exact schemas for application.status.changed, consent.updated, verification.completed, eligibility.completed, lender.application.submitted, lender.decision.received, loan.offer.created and loan.offer.accepted before their implementation. Capture revision, verification, snapshot and evaluation request identifiers wherever results depend on them. The other reserved Kafka topics are preparation only.

Before later branches, define application revision committed, financial refresh, information acknowledgement, offer decline/expiry/withdrawal, cancellation acknowledgement and processing-health events. Document command idempotency and state/version guards for every mutation. Keep source-owned DTOs separate; do not introduce a shared domain/entity library.
