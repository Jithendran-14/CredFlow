# Member 1, Member 2 and Member 3 contract alignment

Updated 2026-10-16. The two supplied upstream documents are preserved verbatim under `contracts/upstream/`. A proposed interface remains proposed even when Member 3 prepares its matching request. This release contains Member 3 backend code and API specifications, with Oracle storage, manual schema setup and no frontend.

## Service addresses and demonstration identifiers

| Service | Address / ownership |
|---|---|
| Application | Member 1, http://localhost:8081; existing create/read APIs |
| Consent and Verification | Member 1, http://localhost:8082 is proposed and must be confirmed |
| Eligibility | Member 2, http://localhost:8083; business HTTP APIs proposed |
| Orchestration | Member 3, http://localhost:8084 |
| Auth | Member 1 custom RS256 Auth, http://localhost:8085; configure exact issuer/key/token endpoints rather than inferring them from this host |
| Audit | Member 2, http://localhost:8086 |
| Lender Integration | Member 3, http://localhost:8087; moved from 8085 to avoid the Auth conflict |
| Member 3 lenders | Bank A http://localhost:8091 and NBFC B http://localhost:8092; the upstream shared provider mock on8090 remains external |
| Financial-data provider mock | Proposed `/mock/v1/verifications/financial-data`; host/port unassigned |

| Demonstration identity | UUID |
|---|---|
| BANK_A lender | bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1 |
| BANK_A product | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1 |
| NBFC_B lender | bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2 |
| NBFC_B product | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2 |

IDs are synthetic seeds from Member 2's contract. Confirm persisted catalog rows before a live journey. No automatic fallback or parallel lender submission is introduced.

## Identity and authentication

Member 3 validates RS256 JWTs against an explicitly configured issuer, audience and public verification key. Set `AUTH_ISSUER`, and exactly one of `JWT_JWKS_URI` or `JWT_PUBLIC_KEY_LOCATION`. The latter is an X.509 RSA public PEM location such as `file:/C:/CredFlow/public-key.pem`; never provide a private key. The RSA key must be at least 2048 bits. Configure the actual Auth token URL separately for machine clients. Port 8085 alone does not reveal the issuer, discovery path or token endpoint.

Default `JWT_ROLE_MODE=FLAT` reads `JWT_ROLE_CLAIM=roles`; a single `role` is accepted when default roles is absent. Claims may be a collection or a whitespace/comma-separated string. `JWT_ROLE_MODE=KEYCLOAK` explicitly supports `resource_access.<roles-client>.roles`; Member 1 custom Auth is not assumed to be Keycloak.

Trusted camelCase `sellerId`, `marketplaceId` and `lenderId` are supported, with legacy snake_case aliases only when the corresponding camelCase claim is absent. String seller IDs such as `SELLER-1001` are not UUIDs. When a workflow stores sellerId, the seller claim must match; a matching sub cannot bypass a mismatching sellerId. Legacy subject ownership applies only to old records without trusted sellerId. A new application with null sellerId stops with `TRUSTED_SELLER_MAPPING_REQUIRED`. marketplaceSellerId and provider fixture identifiers remain separate references.

Member 1 MARKETPLACE receives only bounded Member 3 marketplace status/queue permissions through the MARKETPLACE_OPERATIONS alias. It gains no seller/lender privileges. Existing Auth lists ADMIN, SELLER and MARKETPLACE only. LENDER_OFFICER and trusted lenderId, designated machine-client IDs and narrow scopes still require Auth/Gateway provisioning. Human ADMIN tokens never substitute for service identities. Missing machine token URL/client credentials fail with SERVICE_AUTHENTICATION_NOT_CONFIGURED rather than an invented Auth call.

## Application event compatibility gate

Member 1 says its publisher is not implemented and describes a flat event using eventVersion. Its full flat JSON shape was not supplied. Member 2 current Audit consumer expects a schemaVersion 1.0 envelope and UUID sellerId. These formats conflict. Member 3 cannot infer the flat event or convert SELLER-1001 into a UUID.

`contracts/events/application.submitted.schema.json` defines a **proposed joint canonical target**: the versioned envelope with trusted sellerId string or null. Member 3 accepts richer context when supplied, including businessProfile, loanPurpose, marketplaceSellerId and legacy sellerSubject. Missing business name or loan purpose stops with APPLICATION_DETAILS_REQUIRED; missing trusted seller mapping stops independently. No business identity, date or financial amount is fabricated.

Before connecting the Application outbox publisher, agree the envelope, source aggregate-version meaning, field population and Audit seller-ID validator change. If Member 1 retains its flat format, provide its complete schema and implement a deliberately versioned adapter with fixtures before enabling it. Kafka ACLs must restrict the real publisher; a producer string is not authentication.

Existing Application GET has no businessProfile. The businessProfile.businessStartDate extension and authenticated internal context/ownership APIs remain Member 1 work. Member 3 does not reuse ADMIN/seller tokens for service calls or query CF_APPLICATIONS directly.

## Consent, verification and financial retrieval

Initial APPLICATION_SHARE_WITH_CREDFLOW evidence does not grant financial consent. Consent and Verification owns seller ownership checks, separate purpose-specific financial consent, expiry/revocation, trusted seller-to-fixture mapping, provider calls and authorised disclosure.

| Boundary | Intended request | Availability |
|---|---|---|
| Consent -> Application | POST `/internal/v1/applications/{applicationId}/ownership-check` | Member 1 proposed |
| Eligibility -> Consent | GET `/internal/v1/applications/{applicationId}/financial-data` | Member 1 proposed |
| Consent -> identity provider | POST `/internal/v1/verification/checks` at shared 8090 | Member 2 proposed HTTP; response/scenario logic exists externally |
| Consent -> financial provider | POST `/mock/v1/verifications/financial-data` | Proposed; host/fixture mapping unassigned |
| Consent -> Orchestration | verification.completed with durable CredFlow verificationId | Member 3 proposed event extension; provider HTTP response is a different contract |

Member 3 calls neither provider directly. The provider fixture is chosen through trusted Consent mapping. Its providerReference is not a CredFlow verification UUID or financial retrieval authorisation.

The private Orchestration -> Consent trigger is configurable through `credflow.paths.consent-verification-trigger` (default `/api/v1/internal/verifications`); that trigger remains an unagreed upstream private contract. It is not `/internal/v1/verification/checks`, which belongs to the identity provider.

A VERIFIED verification.completed must supply a trusted authorisedRetrievalReference before Orchestration can request Eligibility. This opaque reference is a joint extension to the durable Consent result, not a field already promised by the identity-provider response. Without it, Orchestration records FINANCIAL_RETRIEVAL_REFERENCE_REQUIRED and creates no Eligibility job. The reference stays private and is omitted from public workflow views.

The upstream financial shapes still differ: Member 1's proposed example has six monthly revenue values and debt obligations; Member 2 requires the last three complete months of grossSales, returnsAmount, payoutAmount, orderCount, returnedOrderCount, coverage and dataset identity/version/retrievedAt. Consent and Eligibility must agree a complete aggregate response. Revenue cannot silently become net sales/payout, and absent values cannot become zero.

## Eligibility command and result

Orchestration queues POST `/internal/v1/eligibility/evaluations` at configured Eligibility 8083 with exactly these business fields:

```json
{
  "evaluationRequestId": "66666666-6666-4666-8666-666666666666",
  "applicationId": "33333333-3333-4333-8333-333333333333",
  "applicationRevision": 1,
  "verificationId": "77777777-7777-4777-8777-777777777777",
  "asOfDate": "2026-10-13",
  "authorisedRetrievalReference": "demo-authorised-source-104"
}
```

The UTC date is captured once per evaluation attempt and reused on retry. Eligibility owns financialSnapshotId; Orchestration allocates no snapshot and sends no seller-provided figures. `contracts/upstream/eligibility-evaluation-request.schema.json` validates the request.

Member 2's 202 operationId/PENDING/statusUrl response, worker and polling endpoint remain proposed. A 202 acknowledges the command only. Member 3 stores optional eligibilityOperationId/eligibilityStatusUrl in the safe workflow projection, validates the returned operation path and invents no polling response or automatic polling worker. The workflow stays ELIGIBILITY_CHECKING until a matching completion. Implement completion publication or agree a polling-result adapter before live progression.

eligibility.completed carries the full Member 2 result, including data.applicationId, asOfDate, requestedAmount, currency and EVALUATED summary amounts/percentage. Orchestration checks root/data application equality, revision, expected evaluationRequestId/verificationId, captured date/amount/currency and immutable result identity. Stale/mismatched results are rejected.

EVALUATED is preliminary calculation, not approval. ACTION_REQUIRED has empty lenderResults and reasons FINANCIAL_DATA_INCOMPLETE, FINANCIAL_DATA_INCONSISTENT or FINANCIAL_DATA_INSUFFICIENT; unknown summaries are omitted. Routing sorts eligible products by routingPriority then productId and requires coverage of the requested amount. Member 2 still owns HTTP endpoints, trusted retrieval and completion outbox publication.

## Audit and shared simulator limits

Provided Audit consumes only its template application.submitted contract and exposes ADMIN GET `/api/v1/applications/{applicationId}/audit`. Member 3's topic list identifies desired consumers, not existing Audit subscriptions. Audit must update seller-ID compatibility and add safe projections for other events before a complete timeline is claimed. Seller audit access remains unavailable.

The Member 2 identity mock is an external module with HTTP/Oracle integration pending. Its H2 draft configuration is not imported here. This release remains Oracle only, with separate users for Orchestration, Integration, Bank A and NBFC B. Actual identity/marketplace module assembly requires their source and tests; the lender simulator does not impersonate them.

## Live integration gates

| Gate | Owner | Member 3 behavior until ready |
|---|---|---|
| Confirm issuer/audience/public key and flat claims | Auth/Gateway | Explicit configurable verifier; no guessed endpoints |
| Provision lender/service identities and scopes | Auth/Gateway | Protected routes deny missing identities/permissions |
| Agree canonical submitted event and publish Oracle outbox | Application + Audit + Orchestration | No inferred flat parser or synthetic publisher |
| Add businessProfile and secure internal context/ownership | Application | Missing context remains ACTION_REQUIRED |
| Implement financial consent, fixture mapping and authorised retrieval | Consent and Verification | Missing trusted retrieval reference remains ACTION_REQUIRED |
| Supply required three-month financial dataset | Consent + Eligibility | No fabricated zeroes or approximate mappings |
| Implement Eligibility worker and result delivery | Eligibility + Orchestration | HTTP acceptance alone does not complete calculation |
| Assemble actual provider modules with Oracle | Member 1/2 + simulator owner | Only supplied lender modules exposed here |
| Update Audit contracts and subscriptions | Audit | Full history remains unverified |
| Run Oracle/Kafka/Gateway and both lenders | All members | Offline tests remain separate from live acceptance |

No private keys, bearer tokens or database passwords are stored in these contracts. No frontend is included.

Missing financial authority can be retried through Member3's existing financial-refresh action once per unchanged revision after authorization is available. FINANCIAL_RETRIEVAL_REFERENCE_REQUIRED starts a new durable Consent verification attempt; the seller never supplies a retrieval reference or financial figures. Normal consent, identity, version and no-dispatch guards remain in force.
