package com.credflow.audit;
import com.fasterxml.jackson.databind.*;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
@Component @ConditionalOnProperty(name="credflow.audit.consumer-enabled",havingValue="true",matchIfMissing=true)
public class ApplicationAuditConsumer {
    private final JdbcTemplate jdbc; private final ObjectMapper json;
    public ApplicationAuditConsumer(JdbcTemplate jdbc,ObjectMapper json) { this.jdbc=jdbc; this.json=json; }
    @Transactional @KafkaListener(topics="application.submitted") public void consume(String payload) throws Exception {
        JsonNode event=json.readTree(payload);
        for(String required:new String[]{"eventId","applicationId","eventType","correlationId","producer","occurredAt","actor","data"})
            if(!event.hasNonNull(required)) throw new IllegalArgumentException("Missing event field: "+required);
        if(!"application.submitted".equals(event.path("eventType").asText())) throw new IllegalArgumentException("Unexpected event type");
        String id=event.path("eventId").asText();
        if(jdbc.queryForObject("SELECT COUNT(*) FROM event_inbox WHERE event_id=?",Integer.class,id)>0) return;
        // Persist only approved envelope/actor fields, never arbitrary producer payloads.
        var safe=json.createObjectNode();
        for(String field:new String[]{"eventId","applicationId","eventType","schemaVersion","correlationId","producer","occurredAt","aggregateVersion","causationId"}) if(event.has(field)) safe.set(field,event.get(field));
        for(String actorField:new String[]{"actor","originActor"}) if(event.has(actorField)) {
            var actor=safe.putObject(actorField);
            for(String field:new String[]{"type","subject","organisationId"}) if(event.path(actorField).has(field)) actor.set(field,event.path(actorField).get(field));
        }
        var data=safe.putObject("data");
        for(String field:new String[]{"sellerId","marketplaceId","requestedAmount","currency","status","applicationRevision","sellerRequestReference"}) if(event.path("data").has(field)) data.set(field,event.path("data").get(field));
        jdbc.update("INSERT INTO audit_event(event_id,application_id,event_type,correlation_id,producer,occurred_at,safe_payload) VALUES(?,?,?,?,?,?,?)",id,event.path("applicationId").asText(),event.path("eventType").asText(),event.path("correlationId").asText(),event.path("producer").asText(),event.path("occurredAt").asText(),json.writeValueAsString(safe));
        jdbc.update("INSERT INTO event_inbox(event_id) VALUES(?)",id);
    }
}
