# Member 3 status transitions

Baseline: `CredFlowDevelopment_Corrected.docx`, Section 16. Orchestration owns application progression after `application.submitted`; Application owns input revisions and its seller-facing projection. API-only delivery is selected. This document describes the implementation; it is not evidence that the joint live demonstration has passed.

## Application business states

| Current state | Accepted trigger and guards | Next state |
| --- | --- | --- |
| AWAITING_CONSENT | Required scopes, source marketplace, application-open validity and purpose are granted | VERIFYING |
| AWAITING_CONSENT | Required consent declined/revoked | CANCELLED |
| VERIFYING | Current verification ID/revision returns PENDING | VERIFYING |
| VERIFYING | Current verification returns ACTION_REQUIRED | ACTION_REQUIRED |
| VERIFYING | Current verification returns FAILED | CHECK_FAILED |
| VERIFYING | Current verification returns VERIFIED | ELIGIBILITY_CHECKING |
| ACTION_REQUIRED | Authorised correction guard, committed next application revision and active consent | VERIFYING |
| ACTION_REQUIRED | Authorised financial refresh for incomplete/inconsistent/insufficient data or missing trusted financial retrieval reference; once per unchanged revision | VERIFYING |
| ELIGIBILITY_CHECKING | Current evaluation/verification/revision returns ACTION_REQUIRED, no lender results and a financial-data reason | ACTION_REQUIRED |
| ELIGIBILITY_CHECKING | EVALUATED has no eligible product whose limit covers the requested amount | NO_ELIGIBLE_LENDER |
| ELIGIBILITY_CHECKING | EVALUATED contains eligible products; lowest routing priority, then product ID | READY_FOR_LENDER |
| READY_FOR_LENDER | Selected lender is a named recipient of current consent; single submission reserved | SUBMITTING |
| READY_FOR_LENDER | Selected recipient consent is absent | Remain READY_FOR_LENDER with SELECTED_LENDER_REQUIRES_CONSENT |
| SUBMITTING | Receipt for the current submission/lender/revision and external ID | LENDER_REVIEW |
| LENDER_REVIEW or MANUAL_REVIEW | Authoritative question details received | INFORMATION_REQUIRED |
| INFORMATION_REQUIRED | All open questions answered and acknowledged by the lender | LENDER_REVIEW |
| LENDER_REVIEW, INFORMATION_REQUIRED or MANUAL_REVIEW | Lender MANUAL_REVIEW decision | MANUAL_REVIEW |
| LENDER_REVIEW, INFORMATION_REQUIRED or MANUAL_REVIEW | Lender REJECTED decision with reason | REJECTED |
| LENDER_REVIEW, INFORMATION_REQUIRED or MANUAL_REVIEW | APPROVED without an offer | Remain in review; APPROVAL_RECEIVED_AWAITING_OFFER |
| LENDER_REVIEW, INFORMATION_REQUIRED or MANUAL_REVIEW | Valid complete offer received | OFFER_AVAILABLE |
| OFFER_AVAILABLE | Owner accepts active offer before current UTC expiry with matching offer version and active recipient consent | OFFER_ACCEPTED |
| OFFER_AVAILABLE | Owner declines active offer with matching version | OFFER_DECLINED |
| OFFER_AVAILABLE | Current UTC expiry passes, or lender withdraws | OFFER_EXPIRED |
| Any nonterminal state | Effective withdrawal, loss of required scope/selected recipient, or authorised seller cancellation | CANCELLED |

An INFORMATION_REQUIRED decision may precede its separate question event. It records an awaiting-question detail; only persisted question details expose an answerable request. A valid offer cancels obsolete open questions using the documented CANCELLED state. A late answer acknowledgement cannot reopen them or reverse the offer state.

Terminal application states are CHECK_FAILED, NO_ELIGIBLE_LENDER, OFFER_ACCEPTED, OFFER_DECLINED, OFFER_EXPIRED, REJECTED and CANCELLED. They have no outgoing business transitions. Receipt/cancellation/acceptance acknowledgements and technical recovery can still be recorded without changing the completed outcome. A new borrowing journey creates a new application.

An ACKNOWLEDGED cancellation/acceptance cannot be downgraded by a later failure. This also applies to a confirmed reference cancellation with no external application ID; a late failure is consumed without waiting for a receipt that may never exist.

## Distinct state machines

| Resource | States / meaning |
| --- | --- |
| Lender submission | CREATED, SENDING, SUBMITTED, INFORMATION_REQUIRED, MANUAL_REVIEW, APPROVED, REJECTED. Cancellation acknowledgement is separate; CANCELLED is not an Orchestration submission decision state. |
| Question | OPEN, ANSWERED, CANCELLED. Seller answers are durably stored while acknowledgement is PENDING; ANSWERED follows lender acknowledgement. |
| Offer | ACTIVE, ACCEPTED, DECLINED, EXPIRED, WITHDRAWN. Application OFFER_EXPIRED covers expiry/withdrawal; the offer retains the specific status. |
| Acceptance delivery | PENDING, ACKNOWLEDGED, FAILED. OFFER_ACCEPTED means local durable acceptance; acknowledgement does not redefine it. |
| Cancellation delivery | Pending/acknowledged/failed independently of the last lender decision. An uncertain request can require reference lookup/cancellation. |
| Technical health | OK, RETRY_PENDING, OUTCOME_UNKNOWN, MANUAL_INTERVENTION_REQUIRED. Network errors never imply lender rejection or failed KYC. |
| Integration dispatch | QUEUED/SENDING/SUBMITTED and operational reconciliation states are internal adapter state, not the application business-state enum. |
| Durable delivery | JOB/INBOX/OUTBOX/DLT rows use PENDING, RUNNING, DONE, DEAD. Integration commands and callbacks have their own bounded retry queues. |

## Identity, ordering and concurrency

`applicationRevision` identifies accepted decision inputs. `workflowVersion` orders Application's status projection. The JPA row version and offer/question version protect concurrent mutation. Integration's event version orders events emitted for its own application aggregate; none of these counters is interchangeable.

Verification must match the expected verification ID and current revision. Orchestration generates `evaluationRequestId` and asks Eligibility to evaluate; Eligibility/its PL/SQL package owns snapshot creation. The first trusted current evaluation result binds its immutable snapshot/result IDs. A changed result for that request is rejected; stale requests/revisions cannot bind a replacement snapshot. Financial refresh generates a new request and a new Eligibility-owned snapshot.

Events from the wrong producer are rejected. Cross-topic early events remain pending until prerequisites and the preceding Integration aggregate version exist. Duplicate inbox/event/task IDs retain their original outcome. Locking the workflow serialises acceptance, effective consent changes, cancellation and correction guards. Offer actions also lock/check the offer and its expected version. No automatic fallback or parallel lender dispatch is implemented.

Queued verification, evaluation, submission and answer HTTP jobs recheck current consent, current expected IDs/revision and workflow state before sending. Obsolete jobs are skipped. Matching cancellation work remains allowed after local cancellation so an external request can be closed.

## Technical issue recovery

The workflow's HEALTH_ISSUES_JSON CLOB keeps one record per durable job/task, not one record per retry. Success becomes a resolved tombstone so a delayed failure for that same task cannot reopen health. Old-revision entries can be removed because all result/job guards reject the old revision. Stable task identity, operation and child-resource binding prevent one successful acknowledgement from hiding another unresolved task.

The workflow API exposes each active issue with its qualified issueId, bare UUID operationId and kind JOB/TASK/CALLBACK. Use operationId directly with the corresponding protected status/replay API; clients do not need to parse a prefix. Callback issues retain their existing persisted task key while exposing kind CALLBACK and the original callback event UUID. The extra response fields do not change stored tombstones or database columns.

Current generic job failures publish RETRY_PENDING, exhausted jobs publish MANUAL_INTERVENTION_REQUIRED, and unknown lender outcomes publish OUTCOME_UNKNOWN. Recovery/acknowledgement resolves the corresponding issue; remaining active issues determine health in this order: OUTCOME_UNKNOWN, MANUAL_INTERVENTION_REQUIRED, RETRY_PENDING, OK. An administrator replays work through protected APIs after investigation. Replay does not bypass consent, revision, owner or idempotency guards.

## Verification still required

Automated offline behavior and configuration tests are separate from Oracle/Kafka/Keycloak evidence. Run the supplied Oracle checks against manually prepared isolated schemas, then the API scenario runner with all teammates' services. Capture status projection ordering, ownership failures, callback correlation, duplicate recovery, database restart behavior and acceptance/expiry/cancellation races before declaring the shared journey complete.

Missing financial authority can be retried through Member3's existing financial-refresh action once per unchanged revision after authorization is available. FINANCIAL_RETRIEVAL_REFERENCE_REQUIRED starts a new durable Consent verification attempt; the seller never supplies a retrieval reference or financial figures. Normal consent, identity, version and no-dispatch guards remain in force.
