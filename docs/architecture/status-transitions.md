# Workflow transition baseline

Orchestration will own later states. Application currently creates AWAITING_CONSENT and stores workflowVersion=0; it has no independent progression implementation.

| State | Trigger | Next state |
|---|---|---|
| AWAITING_CONSENT | Required consent effectively granted | VERIFYING |
| AWAITING_CONSENT | Required consent declined | CANCELLED |
| VERIFYING | Pending verification | VERIFYING |
| VERIFYING | Correction needed | ACTION_REQUIRED |
| VERIFYING | Failed identity check | CHECK_FAILED |
| VERIFYING | Verified business checks | ELIGIBILITY_CHECKING |
| ELIGIBILITY_CHECKING | Missing/zero/inconsistent required data | ACTION_REQUIRED |
| ACTION_REQUIRED | Accepted correction/authorised refresh with committed revision | VERIFYING |
| ELIGIBILITY_CHECKING | No eligible products | NO_ELIGIBLE_LENDER |
| ELIGIBILITY_CHECKING | Eligible products | READY_FOR_LENDER |
| READY_FOR_LENDER | Selected submission created | SUBMITTING |
| SUBMITTING | Lender receipt confirmed | LENDER_REVIEW |
| LENDER_REVIEW or MANUAL_REVIEW | Questions received | INFORMATION_REQUIRED |
| INFORMATION_REQUIRED | Answer acknowledged by lender | LENDER_REVIEW |
| LENDER_REVIEW or INFORMATION_REQUIRED | Manual review referral | MANUAL_REVIEW |
| LENDER_REVIEW, MANUAL_REVIEW or INFORMATION_REQUIRED | Rejection | REJECTED |
| LENDER_REVIEW, MANUAL_REVIEW or INFORMATION_REQUIRED | Approval plus complete valid offer | OFFER_AVAILABLE |
| OFFER_AVAILABLE | Atomic seller acceptance before expiry | OFFER_ACCEPTED |
| OFFER_AVAILABLE | Decline | OFFER_DECLINED |
| OFFER_AVAILABLE | Expiry or lender withdrawal | OFFER_EXPIRED |
| Cancellable nonterminal state | Cancellation/effective required consent withdrawal | CANCELLED |

Terminal: CHECK_FAILED, NO_ELIGIBLE_LENDER, OFFER_ACCEPTED, OFFER_DECLINED, OFFER_EXPIRED, REJECTED, CANCELLED. No outgoing business transitions in the MVP. Terminal withdrawal changes future permission use, not the historical outcome.

Technical health is separate: OK, RETRY_PENDING, OUTCOME_UNKNOWN, MANUAL_INTERVENTION_REQUIRED. Network failures never become lender rejections. Apply events only after checking prerequisites, current state, input revision, expected result IDs and versions. Delay early events until prerequisites exist; inbox receipt must not silently discard unprocessed business work.
