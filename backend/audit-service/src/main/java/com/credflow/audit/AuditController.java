package com.credflow.audit;
import java.util.List;
import com.fasterxml.jackson.databind.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
@RestController public class AuditController {
    private final JdbcTemplate jdbc; private final ObjectMapper json;
    public AuditController(JdbcTemplate jdbc,ObjectMapper json) { this.jdbc=jdbc; this.json=json; }
    @GetMapping("/api/v1/applications/{id}/audit") @PreAuthorize("hasRole('ADMIN')")
    public List<JsonNode> read(@PathVariable String id) {
        return jdbc.query("SELECT safe_payload FROM audit_event WHERE application_id=? ORDER BY occurred_at,event_id",(rs,n)->{
            try { return json.readTree(rs.getString(1)); } catch(Exception ex) { throw new IllegalStateException("Stored audit event is invalid",ex); }
        },id);
    }
}
