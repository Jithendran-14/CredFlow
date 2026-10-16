# Ownership and backend handoff

This release follows CredFlow_Team_Work_Allocation.docx and
CredFlowDevelopment_Corrected.docx. The user's later instructions take precedence:
Oracle replaces the simulator's documented H2 storage, schema changes remain
manual, and frontend work is excluded from this release.

| Owner | Contribution and acceptance boundary |
| --- | --- |
| Member 3 | Orchestration, Integration, Bank A/NBFC B APIs and simulator assembly boundary; workflow/routing, information/offer actions, durable delivery, own SQL reports/tests/logging and API contracts. This source is supplied in the release. |
| Member 1 | Application, Consent/Verification, Gateway/Auth, seller/organisation mappings, marketplace simulator records and corresponding fixture import. Their implementation and deployed configuration were not supplied. |
| Member 2 | Eligibility, Audit, Kafka/Oracle infrastructure, financial SQL/PLSQL package and verification fixtures. Their implementation and deployed configuration were not supplied. |
| Shared acceptance | Agree the supplied boundary contracts, combine the actual marketplace/provider modules in the simulator, run both lender journeys and capture failure/race/access/audit evidence against the real services; the upstream drafts mark their missing APIs explicitly. |

The shared platform module contains infrastructure code, not shared business
entities. Orchestration and Integration have separate durable tables under their
own users. Bank A and NBFC B run as independent applications on 8091 and 8092, each with its own Oracle user.
No service queries another service's business schema.

## Review and integration order

1. Import the clean source and review the included changes and verification
   report. Keep individual commits under the actual author's identity; the source
   bundle does not fabricate contribution history or attendance evidence.
2. Create the manual tables from the mapping checklist. Configure real secrets
   and validate all four Oracle owners with the opt-in tests.
3. Members 1/2 compare their endpoints/events with `docs/api-integration.md`, the
   OpenAPI definitions, data dictionary and per-topic event schemas. Update both
   sides together when an actual team contract differs.
4. Confirm JWT roles, organisation claims, target audiences, machine scopes,
   Kafka topic ACLs and Gateway routes before running business scenarios.
5. Run `scripts/Test-Contracts.ps1`, seed the fictional fixture definitions in the
   owning teammate modules and run the API demo for each lender. Complete
   `docs/acceptance-checklist.md` with real evidence.

The default Maven build checks selected behavior and offline wiring. It is not
proof of a complete deployed team system. The verification report explicitly
lists unrun checks. No frontend or automatic migration is included.

The later supplied contracts are copied verbatim under contracts/upstream. Use docs/team-contract-alignment.md for the final handoff gates. Integration moved to8087 because Auth owns8085. No owner receives another member's credentials or direct schema access.
