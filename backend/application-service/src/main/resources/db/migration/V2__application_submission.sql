CREATE TABLE seller_profile (
 seller_id VARCHAR2(36) PRIMARY KEY, marketplace_id VARCHAR2(36) NOT NULL,
 marketplace_seller_id VARCHAR2(100) NOT NULL, keycloak_subject_id VARCHAR2(100) NOT NULL,
 CONSTRAINT uq_marketplace_seller UNIQUE(marketplace_id, marketplace_seller_id)
);
CREATE TABLE loan_application (
 application_id VARCHAR2(36) PRIMARY KEY, application_reference VARCHAR2(50) NOT NULL UNIQUE,
 seller_id VARCHAR2(36) NOT NULL REFERENCES seller_profile(seller_id), marketplace_id VARCHAR2(36) NOT NULL,
 marketplace_request_id VARCHAR2(100) NOT NULL, requested_amount NUMBER(19,2) NOT NULL,
 currency VARCHAR2(3) NOT NULL CHECK(currency='INR'), loan_purpose VARCHAR2(50) NOT NULL,
 status VARCHAR2(50) NOT NULL, application_revision NUMBER(10) DEFAULT 1 NOT NULL,
 version NUMBER(10) DEFAULT 1 NOT NULL, workflow_version NUMBER(10) DEFAULT 0 NOT NULL,
 request_json CLOB NOT NULL, created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 CONSTRAINT ck_amount_positive CHECK(requested_amount>0),
 CONSTRAINT uq_marketplace_request UNIQUE(marketplace_id,marketplace_request_id)
);
CREATE INDEX ix_application_seller ON loan_application(seller_id,marketplace_id,status);
CREATE TABLE api_idempotency (
 caller_subject VARCHAR2(100) NOT NULL, idempotency_key VARCHAR2(100) NOT NULL,
 payload_hash VARCHAR2(64) NOT NULL, application_id VARCHAR2(36) NOT NULL REFERENCES loan_application(application_id),
 PRIMARY KEY(caller_subject,idempotency_key)
);
