# Developer ownership and first tasks

| Owner | Modules | Next tasks | Completion check |
|---|---|---|---|
| Member 1 | Application, Consent and Verification, Gateway, marketplace simulator | Add protected internal ownership checks; consent grant/decline with queued operation status; retrieval and verification commands; seeded seller evidence validation | Only an application's seller can consent; protected checks begin only after effective consent; `consent.updated` and `verification.completed` are durable and duplicate-safe |
| Member 2 | Eligibility, Audit, verification fixtures, Kafka and Oracle coordination | Build imported financial tables and immutable snapshots; CF_FINANCIAL_SUMMARY_PKG; versioned product rules; Oracle fixture tests; extend Audit to agreed events | Fixture returns average net sales 550000.00 and both eligible products; missing/zero/inconsistent data have explicit results; Audit deduplicates every implemented event |
| Member 3 | Orchestration, Lender Integration, Bank A/NBFC B simulator modules | Consume submitted/consent/verification events with inboxes; guard transitions; select Bank A; implement stable submission reference, callbacks, offer and acceptance | One correlated journey reaches OFFER_ACCEPTED; duplicate callbacks do not repeat transitions; lender acknowledgement is tracked separately |

`platform-support` contains only technical helpers. Each service owns its migrations, security, DTOs, tests, events and logs. All members review contracts and fix integration defects in their own services.

## First integration checkpoints

1. Day 2: login/client token, gateway, six schemas and event infrastructure run on every developer machine. Assign owners to unresolved payload fields in `contracts/day6-flow.md`.
2. Day 3: submission reaches Orchestration and Audit. Add authoritative workflow rows and status projection consumption.
3. Day 4: effective consent triggers verification, then authorised financial retrieval and snapshot generation.
4. Day 5: eligibility selects Bank A and lender confirms receipt using the stable submission ID.
5. Day 6: valid offer can be accepted once; show Oracle SQL/PLSQL outputs, test results and correlated audit/log evidence.

After Day 6 add NBFC B, information requests, manual review and rejection (Days 7–10); missing/zero-data recovery, cancellation, stale results and races (Days 11–12); security/integration checks and optional UI (Days 13–16). Freeze features at end of Day 16. Rehearse and fix defects on Days 17–19.

Use branch names such as `feature/m1-consent`, `feature/m2-financial-snapshot`, and `feature/m3-bank-a-flow`. Avoid changing historical Flyway migrations after anyone has applied them; add a new numbered migration instead.
