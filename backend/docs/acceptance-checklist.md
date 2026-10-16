# Backend acceptance evidence

The default build verifies selected logic and local application wiring. Record
the actual live result, application ID, correlation ID, fixture and evidence path
for every scenario below. A blank result is pending. Do not infer live success
from file presence or mock-based tests.

| Scenario | Member 3 responsibility | Live result and evidence |
| --- | --- | --- |
| Bank A INR500000 journey | Route, normalize, record offer, accept locally, separate lender ACK | Pending shared services |
| NBFC B journey | Different format, same business behavior, no Bank A fallback | Pending shared services |
| One/both/no eligible products | Deterministic routing, correct no-lender terminal outcome | Pending shared services |
| Financial missing/zero and correction | ACTION_REQUIRED, guarded refresh/revision and stale result rejection | Pending Member 1/2 fixtures |
| Consent pending/declined/revoked | No unauthorized sharing; cancellation and separate external ACK | Pending shared services |
| Questions and answers | Correct submission binding, structured answers, resumed review/status | Pending shared services |
| Manual review and rejection | Authoritative lender callback and reasoned terminal rejection | Pending shared services |
| Accept, decline, expire and withdraw | Version guards, UTC expiry, immutable terminal result | Pending shared services |
| Acceptance versus expiry/withdrawal/cancellation race | One committed result under Oracle locks | Pending live concurrency |
| Timeout after lender commit | Query stable reference before any creation retry | Pending fault injection |
| Duplicate command/callback/event | Same payload replay, conflicting payload409, no duplicate acceptance | Pending Oracle/Kafka |
| Process restart/retry exhaustion/replay | Durable work survives; authorized replay retains IDs and trace | Pending live restart |
| Seller/lender/marketplace isolation | Wrong resource/org concealed; internal clients/scopes constrained | Pending deployed configured Auth |
| Audit and status projection | Member 1/2 receive current versions, actors, origin and correlation | Pending Member 1/2 |
| SQL and PL/SQL proof | Own SQL reports; consume Member 2's genuine package result | Pending Oracle fixtures |

## API runner

`scripts/Invoke-Member3Demo.ps1` covers the connected normal journey, optional
information/manual review, acceptance replay and lender ACK, plus selectable
decline, expiry, withdrawal, rejection and cancellation. It requires the actual
Gateway and seeded identities. It records its own passed flag and safe responses.

## Failure and race procedure

1. Capture a clean baseline with current versions and correlation ID.
2. For a timeout, interrupt the Integration-to-simulator response after the
   simulator commits; restore connectivity and confirm lookup finds the same
   external ID, with exactly one persisted case and no second lender selection.
3. Stop each service after its transaction commits and before external delivery;
   restart and confirm stable event IDs, lease recovery and one applied outcome.
4. Deliver duplicate and out-of-order callbacks; verify original event IDs and
   prerequisite handling, correct sequence and resource bindings.
5. Run simultaneous acceptance and expiry/withdrawal/effective cancellation against
   the same expected versions. Capture both responses and the final Oracle rows.
6. Exhaust a dependency job, inspect processingIssues and the protected queue API,
   restore the dependency and replay only the recorded operation. Confirm unrelated
   unresolved issues remain visible.
7. Attempt each read/action with the other seller, lender and marketplace token;
   check401/403/404 semantics from the access matrix and absence of record leakage.
8. Match Application's projected workflowVersion and Audit's actor/origin/causation
   with the authoritative Orchestration result and correlated service logs.

Fault injection belongs in a controlled local demo environment and is not enabled
as a public application API. The runner does not delete records or alter schemas.

## Team evidence ownership

Member 1 supplies Gateway/configured Auth, seller mappings, marketplace data and consent
integration. Member 2 supplies Oracle/Kafka setup, financial package fixtures,
Eligibility and Audit. Member 3 supplies its backend endpoints, lender behavior,
own SQL reports and coordinated boundary evidence. No frontend is in this release.

## Additional new-contract evidence

Confirm the real Auth issuer/audience/public verification key and provision lender/machine permissions. Resolve the flat submitted-event versus canonical envelope and string-versus-UUID seller conflict with Application/Audit. Prove the exact six-field Eligibility POST, stable UTC asOfDate/retrieval reference and durable returned operationId/statusUrl. Test incomplete/inconsistent/insufficient data and root/data result mismatch. Do not claim readiness from proposed HTTP paths; complete the upstream gates in docs/team-contract-alignment.md first. The API runner now takes -ApplicationId and performs Member3 actions only.
