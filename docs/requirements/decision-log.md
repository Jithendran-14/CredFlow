# Implementation baseline v1.1

This log records the training defaults agreed for implementation. The source development plan and these defaults describe planned behaviour; the implementation status document states what currently works.

| Decision | Baseline |
|---|---|
| Ownership | Application owns relationships. Protected service-to-service lookup supplies only required resource permissions. Unavailable checks return retriable 503; concealed inaccessible resources return 404. No ownership cache initially. |
| Financial period | Last three complete calendar months relative to captured asOfDate; current partial month excluded. Missing coverage is never zero. |
| Zero months | Complete zero months remain in the denominator of three. Continue if total three-month gross sales is positive. Total zero → ACTION_REQUIRED/FINANCIAL_DATA_INSUFFICIENT. |
| Incomplete/inconsistent source | Missing coverage → FINANCIAL_DATA_INCOMPLETE. Returns above gross or returned-order count above orders → FINANCIAL_DATA_INCONSISTENT. Both require action, not lender rejection. |
| Money | Decimal strings with two places; BigDecimal and NUMBER(19,2). No binary floating-point calculations. |
| Limits | Compute totalNetSales × multiplier ÷ 3 directly, without intermediate rounding. Final monetary results use HALF_UP to two decimals. Compare request to final two-decimal indicative limit. |
| Return rate | Compare totalReturns × 100 <= totalGrossSales × thresholdPercent using exact decimals. Display percentages to two places with HALF_UP; multipliers support four places. |
| Products/purposes | Both seeded working-capital products support PURCHASE_INVENTORY and WORKING_CAPITAL. BUSINESS_EXPANSION is valid input but has no supported seed product. Include supportedLoanPurposes in versioned configuration. |
| Bank A | Age >=12 months; average monthly net sales >=300000.00; returns <=15%; amount 100000.00–1000000.00; multiplier 1.0000; priority 1. |
| NBFC B | Age >=6 months; average monthly net sales >=150000.00; returns <=25%; amount 50000.00–800000.00; multiplier 1.0000; priority 2. |
| Routing | Lowest priority eligible product, then productId ascending; one lender once per application. |
| Consent | Application-specific; valid until withdrawal/closure. Named sources and recipients; missing selected recipient requires fresh consent. Effective changes and races serialized by Orchestration. |
| Versions | version for row concurrency; applicationRevision for evaluated inputs; workflowVersion for status projection. Match expected verification/snapshot/evaluation IDs. |
| Queued mutations | 202 with operationId and status URL; PENDING, SUCCEEDED, FAILED. Status inherits original resource permissions. Receipt is durable command acceptance, not completion. |
| Submission idempotency | Caller subject + key + canonical typed-request hash. Same key and body returns same resource; different body returns 409. One active application per seller/marketplace; marketplaceRequestId unique per marketplace. |
| Acceptance | OFFER_ACCEPTED means local durable acceptance. Lender acknowledgement remains PENDING/ACKNOWLEDGED/FAILED independently. |
| Demo | asOfDate 2026-10-13, Jul–Sep 2026; monthly gross 600000.00, returns 50000.00, payouts 530000.00. Average net 550000.00, displayed return rate 8.33%, both eligible for 500000.00, route to Bank A. |

Next contract decisions are endpoint payload details and guarded command sequencing for the unimplemented services; see `contracts/day6-flow.md`. Changes must update examples, schemas, implementation and tests together.
