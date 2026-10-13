# Shared data dictionary

| Field | Type | Owner | Meaning |
|---|---|---|---|
| applicationId | UUID | Application | Internal resource ID |
| applicationReference | String | Application | Readable reference distinct from ID |
| sellerId | UUID | Application | Registered seller business entity |
| marketplaceId | UUID | Application/configuration | Organisation; must match authenticated caller for submission |
| marketplaceSellerId | String <=100 | Marketplace | Source seller reference; not necessarily UUID |
| marketplaceRequestId | String <=100 | Marketplace | Unique within marketplace |
| keycloakSubjectId | String | Identity/Application | Stable authenticated subject linking human to seller |
| applicationRevision | Positive integer | Application | Changes when accepted decision inputs change |
| version | Positive integer | Owning service | Mutable-row optimistic concurrency |
| workflowVersion | Nonnegative integer | Orchestration | Orders seller-facing status projections |
| consentId/consentVersion | UUID/integer | Consent | Application-specific permission record and version |
| verificationId | UUID | Consent | Version-linked verification result |
| financialSnapshotId | UUID | Eligibility | Immutable source snapshot |
| evaluationRequestId | UUID | Orchestration/requester | Identifies expected evaluation job |
| submissionId | UUID | Orchestration | Stable external submission idempotency reference |
| eventId | UUID | Producer | Stable across delivery retries |
| aggregateVersion | Positive integer | Producer | Local aggregate order; not cross-topic workflow order |
| correlationId | String <=100 | First boundary | Trace across calls/events |
| actor/originActor | Structured identity | Trusted boundary | Immediate actor and originating actor, separate from producer |
| amount | Decimal string with two places | Owning object | INR, nonnegative; request amount strictly positive |

Actual implemented validation is in OpenAPI and the Java request DTO. Future result, offer and operation schemas must be completed with required fields before use. DTOs are copied/owned through versioned contracts, never shared database entities.
