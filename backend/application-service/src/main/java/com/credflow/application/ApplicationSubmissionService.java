package com.credflow.application;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service public class ApplicationSubmissionService {
    private final JdbcTemplate jdbc; private final ObjectMapper json;
    public ApplicationSubmissionService(JdbcTemplate jdbc,ObjectMapper json) { this.jdbc=jdbc; this.json=json; }
    @Transactional public ApplicationView submit(ApplicationRequest request,String key,Jwt actor,String correlationId) {
        if(key==null || !key.matches("[A-Za-z0-9._-]{1,100}")) throw failure(HttpStatus.BAD_REQUEST,"INVALID_IDEMPOTENCY_KEY","Supply an Idempotency-Key of 1 to 100 letters, digits, dots, underscores or hyphens.");
        if(actor.getSubject()==null || actor.getSubject().length()>100) throw failure(HttpStatus.FORBIDDEN,"INVALID_ACTOR","Authenticated subject is required.");
        if(!request.marketplaceId().toString().equals(actor.getClaimAsString("organisationId"))) throw failure(HttpStatus.FORBIDDEN,"MARKETPLACE_MISMATCH","Marketplace does not match the authenticated organisation.");
        BigDecimal amount=new BigDecimal(request.requestedAmount());
        if(amount.signum()<=0) throw failure(HttpStatus.BAD_REQUEST,"INVALID_AMOUNT","Requested amount must be positive.");
        String encoded=encode(request); String hash=hash(encoded);
        var existing=findIdempotency(actor.getSubject(),key);
        if(!existing.isEmpty()) return replay(existing.getFirst(),hash);
        var sellers=jdbc.queryForList("SELECT seller_id FROM seller_profile WHERE marketplace_id=? AND marketplace_seller_id=? FOR UPDATE",request.marketplaceId().toString(),request.marketplaceSellerId());
        if(sellers.isEmpty()) throw failure(HttpStatus.NOT_FOUND,"SELLER_NOT_FOUND","Seller is not registered for this marketplace.");
        // Seller-row lock serializes concurrent creates for the same seller; check the key again after waiting.
        existing=findIdempotency(actor.getSubject(),key);
        if(!existing.isEmpty()) return replay(existing.getFirst(),hash);
        String seller=(String)sellers.getFirst().get("SELLER_ID");
        Integer active=jdbc.queryForObject("SELECT COUNT(*) FROM loan_application WHERE seller_id=? AND marketplace_id=? AND status NOT IN ('CHECK_FAILED','NO_ELIGIBLE_LENDER','OFFER_ACCEPTED','OFFER_DECLINED','OFFER_EXPIRED','REJECTED','CANCELLED')",Integer.class,seller,request.marketplaceId().toString());
        if(active!=null && active>0) throw failure(HttpStatus.CONFLICT,"APPLICATION_ALREADY_ACTIVE","This seller already has an active application for the marketplace.");
        String id=UUID.randomUUID().toString(); String reference="CF-"+id;
        jdbc.update("INSERT INTO loan_application(application_id,application_reference,seller_id,marketplace_id,marketplace_request_id,requested_amount,currency,loan_purpose,status,request_json) VALUES(?,?,?,?,?,?,?,?,?,?)",id,reference,seller,request.marketplaceId().toString(),request.marketplaceRequestId(),amount,request.currency().name(),request.loanPurpose().name(),"AWAITING_CONSENT",encoded);
        jdbc.update("INSERT INTO api_idempotency(caller_subject,idempotency_key,payload_hash,application_id) VALUES(?,?,?,?)",actor.getSubject(),key,hash,id);
        String eventId=UUID.randomUUID().toString();
        var event=new LinkedHashMap<String,Object>();
        event.put("eventId",eventId); event.put("eventType","application.submitted"); event.put("schemaVersion","1.0"); event.put("occurredAt",Instant.now().toString());
        event.put("producer","application-service"); event.put("applicationId",id); event.put("aggregateVersion",1); event.put("correlationId",correlationId);
        Object access=actor.getClaims().get("realm_access");
        boolean systemClient=access instanceof Map<?,?> rolesMap
            && rolesMap.get("roles") instanceof Collection<?> roles && roles.contains("MARKETPLACE_CLIENT");
        event.put("actor",Map.of("type",systemClient?"SYSTEM_CLIENT":"HUMAN","subject",actor.getSubject(),"organisationId",request.marketplaceId().toString()));
        event.put("data",Map.of("sellerId",seller,"marketplaceId",request.marketplaceId().toString(),"requestedAmount",request.requestedAmount(),"currency","INR","status","AWAITING_CONSENT","applicationRevision",1,"sellerRequestReference",request.sellerRequestReference()));
        jdbc.update("INSERT INTO event_outbox(event_id,application_id,event_type,payload) VALUES(?,?,?,?)",eventId,id,"application.submitted",encode(event));
        return load(id);
    }
    public ApplicationView read(String id,Jwt actor,boolean admin,boolean marketplace) {
        ApplicationView result=load(id);
        String sellerSubject=jdbc.queryForObject("SELECT keycloak_subject_id FROM seller_profile WHERE seller_id=?",String.class,result.sellerId());
        if(!admin && !Objects.equals(sellerSubject,actor.getSubject()) && !(marketplace && result.marketplaceId().equals(actor.getClaimAsString("organisationId")))) throw failure(HttpStatus.NOT_FOUND,"APPLICATION_NOT_FOUND","Application was not found.");
        return result;
    }
    private List<Map<String,Object>> findIdempotency(String subject,String key) { return jdbc.queryForList("SELECT payload_hash,application_id FROM api_idempotency WHERE caller_subject=? AND idempotency_key=?",subject,key); }
    private ApplicationView replay(Map<String,Object> entry,String hash) {
        if(!hash.equals(entry.get("PAYLOAD_HASH"))) throw failure(HttpStatus.CONFLICT,"IDEMPOTENCY_CONFLICT","This key was already used with a different request.");
        return load((String)entry.get("APPLICATION_ID"));
    }
    private ApplicationView load(String id) {
        var rows=jdbc.query("SELECT * FROM loan_application WHERE application_id=?",(rs,n)->new ApplicationView(rs.getString("application_id"),rs.getString("application_reference"),rs.getString("seller_id"),rs.getString("marketplace_id"),rs.getBigDecimal("requested_amount").toPlainString(),rs.getString("currency"),rs.getString("loan_purpose"),rs.getString("status"),rs.getInt("application_revision"),rs.getInt("version"),rs.getInt("workflow_version")),id);
        if(rows.isEmpty()) throw failure(HttpStatus.NOT_FOUND,"APPLICATION_NOT_FOUND","Application was not found.");
        return rows.getFirst();
    }
    private String encode(Object value) { try { return json.writeValueAsString(value); } catch(Exception ex) { throw new IllegalStateException("Could not serialize accepted input",ex); } }
    private static String hash(String value) { try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8))); } catch(NoSuchAlgorithmException ex) { throw new IllegalStateException(ex); } }
    private static BusinessException failure(HttpStatus status,String code,String message) { return new BusinessException(status,code,message); }
}
