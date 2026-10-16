# Member 3 access matrix

All protected calls validate RS256 signatures, explicit issuer/audience, subject, expiry and configured roles/scopes. Auth public material is an explicitly configured JWKS URL or public RSA PEM. Flat roles are the default; the claim name is configurable. KEYCLOAK mode must be selected explicitly for legacy resource roles. Tokens/credentials are never returned by these APIs. The Gateway is an additional boundary; protected services enforce their own checks.

## Resource checks

| Identity | Trusted relationship | Permissions |
| --- | --- | --- |
| SELLER | Trusted JWT sellerId equals the stored opaque sellerId; legacy subject comparison is used only when no trusted sellerId exists | Own application workflow, questions, offers and permitted seller mutations |
| MARKETPLACE (alias MARKETPLACE_OPERATIONS) | marketplaceId is a UUID matching the application's marketplaceId | Read workflow/status and the safe submission queue; items and total count are filtered to that marketplace. No question answers, offers or full submission profile. |
| LENDER_OFFICER | lenderId (legacy lender_id) equals the selected submission lender; lender.review scope for commands | Relevant lender queue/details/questions; commands to that lender only |
| ADMIN | ADMIN role | Authorised read/monitoring; protected replay additionally requires ops.replay; no general seller impersonation |
| Orchestration system | Exact configured orchestration client plus required scope | Internal Integration reservation/commands/status |
| Integration system | Exact configured integration client plus required scope | Workflow dispatch authorisation; simulator submit/lookup/commands |
| Application system | Exact configured application client plus workflow.revision | Correction guard/abort |
| Consent system | Exact configured consent client plus workflow.consent | Serialised consent operation |
| Bank A / NBFC B system | Separate configured callback client identity bound to the route lender plus lender.callback | Only that lender's callbacks |

A public request's seller/lender/marketplace identifiers never establish ownership. Marketplace identity is taken from trusted claims, not a caller-selected query filter. Missing organisation claims deny access. A conflicting lender filter returns 404. Resource ownership checks conceal inaccessible individual resources as 404; missing permissions/scopes return 403.

## Endpoint families

| Owner | Endpoint / action | Caller and guard |
| --- | --- | --- |
| Orchestration | GET /api/v1/applications/{id}/workflow | Seller owner, relevant lender officer, matching marketplace operations, authorised admin read |
| Orchestration | GET /api/v1/applications/{id}/offers | Seller owner, relevant lender officer, authorised admin read; marketplace operations denied; paginated response |
| Orchestration | GET /api/v1/applications/{id}/information-requests | Seller owner, relevant lender officer, authorised admin read; marketplace operations denied; paginated response |
| Orchestration | GET /api/v1/submissions | Lender officer restricted to trusted lenderId; operations restricted to trusted marketplaceId; admin read |
| Orchestration | GET /api/v1/submissions/{id} | Seller owner, matching lender officer or authorised admin; marketplace operations denied full profile/detail access |
| Orchestration | POST /api/v1/offers/{id}/acceptance or /decline | Seller owner; Idempotency-Key; expectedOfferVersion; current state/expiry/consent guards |
| Orchestration | POST /api/v1/information-requests/{id}/responses | Seller owner; Idempotency-Key; expectedInformationVersion; current open question and consent |
| Orchestration | POST /api/v1/applications/{id}/cancellation or /financial-refresh | Seller owner; Idempotency-Key; expectedWorkflowVersion and allowed workflow state |
| Orchestration (private) | GET /api/v1/internal/submissions/{id}/authorization | Configured Integration machine client; workflow.internal |
| Orchestration (private) | POST /api/v1/internal/applications/{id}/revision-guard or /revision-abort | Configured Application machine client; workflow.revision; expected/new input revision |
| Orchestration (private) | POST /api/v1/internal/applications/{id}/consent-operations | Configured Consent machine client; workflow.consent; consent version/idempotent operation |
| Integration (private) | POST /api/v1/internal/submissions; GET /api/v1/internal/submissions/{id} | Orchestration client; integration.write; complete dispatch binding |
| Integration (private) | POST /api/v1/internal/submissions/{id}/information-responses, /offer-acceptances, /offer-declines, /cancellation | Orchestration client; integration.write; stable command UUID/idempotency and child-resource binding |
| Integration | POST /api/v1/submissions/{id}/decisions, /information-requests, /offers, /offer-withdrawals | Matching LENDER_OFFICER and lender.review; public actor/timestamp fields do not establish provenance |
| Integration | POST /api/v1/lenders/{lenderId}/callbacks | Exact lender callback machine identity and lender.callback; submission/revision/external-ID/sequence binding |
| Integration (private) | GET /api/v1/internal/integration-tasks/{id}; POST /{id}/replay | ADMIN and ops.replay; bounded retry/replay and stable original task/callback identity |
| Common delivery operations (private, O/I) | GET /api/v1/internal/deliveries; GET /{kind}/{id}; POST /{kind}/{id}/replay | ADMIN and ops.replay; safe status metadata only, never arbitrary payload access |
| Simulator (private) | /mock/lenders/bank-a/applications and reference lookup; /mock/lenders/nbfc-b/cases and reference lookup | Configured Integration client; lender.submit or lender.lookup |
| Simulator (private) | Command/cancellation-by-reference and command lookup routes | Configured Integration client; lender.command or lender.lookup |
| Simulator (private) | POST /mock/lenders/{bank}/callbacks/{eventId}/replay | Configured Integration client with ops.replay; matching lender namespace and DEAD callback |
| All four applications | GET /actuator/health | Public liveness-style health endpoint; no business records or detailed secrets |

Gateway routing must expose only the public business API families needed by later clients. Internal `/api/v1/internal/**`, simulator `/mock/**` and operational replay routes require a private operations/service boundary. Infrastructure JWT audiences, client scopes and role/organisation mappers remain a joint Member 1 integration task; the source defaults do not prove deployed Auth configuration.

## Provenance and data handling

Immediate actor identity comes from authentication. Trusted internal jobs/events carry originActor and causationId; the original correlation ID continues through adapters, simulator callbacks and emitted events. Each independently deployed lender has its own callback identity and process. Kafka producer ACLs are necessary because producer strings inside JSON are not authentication.

Logs/reports expose safe IDs, statuses and error codes. They omit access tokens, passwords, raw answers, identity documents and transaction source records. SQL reports connect as their owning schema; a report does not bypass service ownership or create a cross-schema join.

## Required security evidence

Test missing/invalid JWT, wrong audience/client/scope, another seller, another marketplace, another lender, forged public actor fields, mismatched callback bindings, conflicting idempotency keys and stale versions. Offline checks do not establish live Auth/Gateway/Kafka access controls; retain actual HTTP status and correlated Audit evidence from the shared environment.

## New team-contract limits

Member1 Auth runs on8085; Integration now runs on8087. Only ADMIN/SELLER/MARKETPLACE human roles exist there today. LENDER_OFFICER, dedicated machine client claims/scopes and token grants still need provisioning. No ADMIN-token workaround is enabled. Member1 Application GET may return403 for ownership failures; Member3 individual-resource concealment remains404 as documented above.
