# Implementation status

| Component | Implemented | Remaining |
|---|---|---|
| Shared foundation | Parent Maven build, wrapper, Java 21 target, JWT checks, roles, correlation, structured logs, CI | Live infrastructure smoke on a Docker machine |
| Gateway | Public route inventory, bearer forwarding, JWT checks, internal route blocking | Route integration coverage for new endpoints; optional UI CORS configuration |
| Application | Create and GET by ID; registered seller mapping; organisation checks; atomic idempotency/active-application guard; safe submitted event | Listing; trusted initial-sharing evidence validation beyond registered relationship and required evidence fields; internal access API; corrections; workflow status projection |
| Application event delivery | Same-transaction outbox; stable event ID; Oracle row locks; up to five publication attempts | Operator replay API/monitoring; live broker verification; backoff refinements |
| Audit | Submitted-event consumer; inbox and safe event storage; bounded consumption retries and DLT; ADMIN query | More event contracts/consumers; pagination; finer admin permissions; authorised DLT replay |
| Consent and Verification | Secured skeleton; schema delivery tables | Consent records, queued changes, provider calls and outcomes |
| Eligibility | Secured skeleton; schema delivery tables; financial fixture | Imported records, package, snapshots, rules and result events |
| Orchestration | Secured skeleton; schema delivery tables | Complete authoritative workflow, commands, projections, operation status and offer guards |
| Lender Integration | Secured skeleton; schema delivery tables | Adapters, submissions, callbacks, information forwarding and reconciliation |
| Simulator | Secured skeleton; separate empty H2 schemas; financial JSON fixture | Marketplace retrieval, KYC scenarios and lender behaviour; distinct outbound client use |

The first implemented slice is submission → pending/published event → Audit. It does not progress beyond AWAITING_CONSENT. No PL/SQL package, lender approval or full happy-path implementation is claimed here.

The submission input records a marketplace assertion of sharing consent. The starter validates the authenticated marketplace relationship and requires its evidence reference; independent evidence verification and its mock source endpoint are Member 1's next task. It must be completed before protected retrieval/verification or lender sharing is introduced.

The Audit GET currently returns the application's safe submitted-event records as an array and is ADMIN-only. Pagination is deliberately deferred and requires a versioned contract change.
