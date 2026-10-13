-- Run as CF_APPLICATION after Flyway V2. MERGE makes repeated seeding safe.
MERGE INTO seller_profile target
USING (SELECT '44444444-4444-4444-8444-000000000104' seller_id FROM dual) source
ON (target.seller_id=source.seller_id)
WHEN NOT MATCHED THEN INSERT (seller_id,marketplace_id,marketplace_seller_id,keycloak_subject_id)
VALUES (source.seller_id,'11111111-1111-4111-8111-111111111111','SELLER-104','70000000-0000-4000-8000-000000000104');
MERGE INTO seller_profile target
USING (SELECT '44444444-4444-4444-8444-000000000105' seller_id FROM dual) source
ON (target.seller_id=source.seller_id)
WHEN NOT MATCHED THEN INSERT (seller_id,marketplace_id,marketplace_seller_id,keycloak_subject_id)
VALUES (source.seller_id,'11111111-1111-4111-8111-111111111111','SELLER-105','70000000-0000-4000-8000-000000000105');
MERGE INTO seller_profile target
USING (SELECT '44444444-4444-4444-8444-000000000106' seller_id FROM dual) source
ON (target.seller_id=source.seller_id)
WHEN NOT MATCHED THEN INSERT (seller_id,marketplace_id,marketplace_seller_id,keycloak_subject_id)
VALUES (source.seller_id,'11111111-1111-4111-8111-111111111111','SELLER-106','70000000-0000-4000-8000-000000000106');
MERGE INTO seller_profile target
USING (SELECT '44444444-4444-4444-8444-000000000107' seller_id FROM dual) source
ON (target.seller_id=source.seller_id)
WHEN NOT MATCHED THEN INSERT (seller_id,marketplace_id,marketplace_seller_id,keycloak_subject_id)
VALUES (source.seller_id,'11111111-1111-4111-8111-111111111111','SELLER-107','70000000-0000-4000-8000-000000000107');
COMMIT;
