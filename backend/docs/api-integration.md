# Backend API integration guide

Member 3 exposes backend APIs for later frontend use and authenticated API demonstrations. No frontend is included. Read `team-contract-alignment.md` first: the supplied Member 1/2 documents identify proposed APIs and incompatible current events. Those external capabilities remain pending.

## Services and identity

| Member 3 service | Direct local URL | Default audience |
|---|---|---|
| Orchestration | http://localhost:8084 | orchestration-service |
| Lender Integration | http://localhost:8087 | lender-integration-service |
| Mock Bank A | http://localhost:8091 | mock-bank-a |
| Mock NBFC B | http://localhost:8092 | mock-nbfc-b |

Port 8085 belongs to Member 1 Auth. Configure its real issuer and public RS256 verification key with AUTH_ISSUER and exactly one of JWT_JWKS_URI or JWT_PUBLIC_KEY_LOCATION. Configure audience for tokens actually issued to each service. Default flat role claims support Member 1 roles and camelCase trusted identity claims; Keycloak mode is opt-in. No Auth endpoint or client credential is guessed.

SELLER ownership uses trusted string sellerId when stored; lender officers require matching lenderId. MARKETPLACE aliases bounded MARKETPLACE_OPERATIONS and requires matching marketplaceId. ADMIN has permitted read/operational access. Existing Auth lacks lender/service identities: provision named clients and scopes before invoking protected routes. ADMIN does not substitute for a service token. See the OpenAPI security descriptions and access matrix.

Send Authorization Bearer, JSON Content-Type, stable X-Correlation-ID and stable Idempotency-Key on applicable mutations. Read current versions before actions. A 409 requires reloading state; a 202 means durable queued work, not lender acknowledgement. Errors are `{code,message,correlationId,fieldErrors}`. Lists are `{items,page,size,totalElements}`, page starts at 0, size 1..100.

## Exposed business APIs

| Caller | Route | Result |
|---|---|---|
| Owner / assigned lender / ADMIN / matching marketplace status role | GET Orchestration `/api/v1/applications/{id}/workflow` | Status, health, versions, optional captured asOfDate and safe issues |
| Owner / assigned lender / ADMIN | GET Orchestration `/api/v1/applications/{id}/offers?page=0&size=20` | Paginated terms, expiry, versions and acceptance acknowledgement |
| Owner / assigned lender / ADMIN | GET Orchestration `/api/v1/applications/{id}/information-requests?page=0&size=20` | Paginated questions and answer history |
| Seller owner | POST Orchestration `/api/v1/information-requests/{id}/responses` | expectedInformationVersion, exact answers and optional synthetic references; 202 operationId |
| Seller owner | POST Orchestration `/api/v1/offers/{id}/acceptance` | expectedOfferVersion; local durable acceptance with separate eventual lender acknowledgement |
| Seller owner | POST Orchestration `/api/v1/offers/{id}/decline` | Versioned/idempotent local decline |
| Seller owner | POST Orchestration `/api/v1/applications/{id}/cancellation` | expectedWorkflowVersion; 202 `{operationId,workflow}` |
| Seller owner | POST Orchestration `/api/v1/applications/{id}/financial-refresh` | Authorized financial ACTION_REQUIRED recovery; expectedWorkflowVersion; 202 operationId |
| Assigned lender / matching marketplace status role / ADMIN | GET Orchestration `/api/v1/submissions?page=0&size=20&lenderId={id}` | Server-filtered lender or marketplace queue |
| Owner / assigned lender / ADMIN | GET Orchestration `/api/v1/submissions/{id}` | Authorized full detail; marketplace status role excluded |
| Assigned lender officer + lender.review | POST Integration `/api/v1/submissions/{id}/decisions` | Queued decision; decidedAt generated once by server |
| Assigned lender officer + lender.review | POST Integration `/api/v1/submissions/{id}/information-requests` | Queued questions |
| Assigned lender officer + lender.review | POST Integration `/api/v1/submissions/{id}/offers` | Queued complete terms |
| Assigned lender officer + lender.review | POST Integration `/api/v1/submissions/{id}/offer-withdrawals` | Queued withdrawal |

Officer commands return 202 `{submissionId,operationId,status:"QUEUED"}` and require UUID Idempotency-Key. APPROVED without full offer terms remains in review. INFORMATION_REQUIRED includes informationRequestId and questions. Synthetic document references are allowed; real upload/disbursement are outside scope. Nonowned resources return 404; missing role/scope is 403.

## Private boundaries

| Caller -> target | Contract and readiness |
|---|---|
| Application -> Orchestration | Proposed canonical application.submitted/revised envelope with trusted string sellerId and context. Member 1 flat event is not supplied; publisher is not implemented. |
| Consent -> Orchestration | POST `/api/v1/internal/applications/{id}/consent-operations`; consent-verification-service + workflow.consent. Member 3 side implemented; upstream caller remains a joint contract. |
| Application -> Orchestration | revision-guard/revision-abort under `/api/v1/internal/applications/{id}`; application-service + workflow.revision. |
| Orchestration -> Consent | Proposed configured private verification trigger. Consent owns durable verification, ownership, provider calls and financial consent. Member 3 calls no provider directly. |
| Consent -> Orchestration | Proposed verification.completed with CredFlow verificationId and trusted authorisedRetrievalReference for progression. Provider HTTP result alone is insufficient. |
| Orchestration -> Eligibility | POST `/internal/v1/eligibility/evaluations`, exact six fields: evaluationRequestId, applicationId, applicationRevision, verificationId, asOfDate, authorisedRetrievalReference. Member 2 endpoint/worker/publication remain proposed. |
| Eligibility -> Orchestration | Proposed eligibility.completed full result; root/data application and expected revision/request/verification/date/amount/currency checked. No invented polling contract. |
| Orchestration -> Integration | POST `/api/v1/internal/submissions` and commands; orchestration-service + integration.write. |
| Integration -> Orchestration | GET `/api/v1/internal/submissions/{id}/authorization`; integration-service + workflow.internal. |
| Integration -> lenders | Bank-specific submission, reference lookup and commands; integration-service + lender.submit/lender.lookup/lender.command. |
| Lender -> Integration | POST `/api/v1/lenders/{lenderId}/callbacks`; lender callback client + lender.callback. Match lender/path/body/dispatch/external ID; 202 `{eventId,status:"PENDING"}`. |
| Orchestration -> Application / Audit | application.status.changed and safe business events. Their projections/subscriptions need implementation and agreement. Current Audit only consumes its template submitted event. |

Use the four service-specific OpenAPI files, event schemas, dictionary and verbatim upstream contracts. Upstream proposed endpoints must be implemented/authenticated before automated calls are enabled. Broad ADMIN credentials do not replace missing service permissions.

## Gateway and future frontend

Use the actual Member 1 Gateway, whose port was not supplied. Route GET submission/detail/workflow/offers/questions and seller mutations to Orchestration 8084. Route lender decision/question/offer/withdrawal POSTs to Integration 8087. Keep internal APIs, callbacks and simulator routes private with machine checks. The login flow must follow Member 1's actual Auth contract; this backend adds no frontend and does not assume Keycloak PKCE.

The CORS allowlist defaults to http://localhost:5173 for future use; it is not authorization. Browser code must never hold machine secrets, callback credentials or Kafka access. After 202 read the available business projections; Member 2's proposed operation status URL is not currently an implemented polling guarantee.

## Inspection, recovery and acceptance

ADMIN + ops.replay can inspect/replay the owning service's `/api/v1/internal/deliveries`. processingIssues identifies operationId and kind. Integration tasks use `/api/v1/internal/integration-tasks/{id}`. Simulator callback replay is `/mock/lenders/{bank}/callbacks/{eventId}/replay`, restricted to integration-service + ops.replay. Preserve original IDs and correct the cause first; successful tasks clear only their own issue.

Unknown submission outcomes require reference lookup before retrying creation. Late callbacks cannot reopen terminal states. Do not create another lender or fresh reference as a timeout workaround.

`scripts/Test-Contracts.ps1` validates schemas, positive/failure fixtures, both journeys and OpenAPI references offline. This does not establish that external APIs, publishers, identities, databases or Gateway routes are live. Complete `team-contract-alignment.md` gates, then run live Oracle/Kafka/Gateway journeys and failure/race/access cases. Manual Oracle setup remains your responsibility.

Missing financial authority can be retried through Member3's existing financial-refresh action once per unchanged revision after authorization is available. FINANCIAL_RETRIEVAL_REFERENCE_REQUIRED starts a new durable Consent verification attempt; the seller never supplies a retrieval reference or financial figures. Normal consent, identity, version and no-dispatch guards remain in force.
