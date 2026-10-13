package com.credflow.application;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.net.URI;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/applications")
public class ApplicationController {
    private final ApplicationSubmissionService service;
    public ApplicationController(ApplicationSubmissionService service) { this.service=service; }
    @PostMapping @PreAuthorize("hasAnyRole('MARKETPLACE_CLIENT','MARKETPLACE_OPERATIONS')")
    public ResponseEntity<ApplicationView> submit(@Valid @RequestBody ApplicationRequest body,
        @RequestHeader(value="Idempotency-Key",required=false) String key,@AuthenticationPrincipal Jwt jwt,HttpServletRequest request) {
        var result=service.submit(body,key,jwt,(String)request.getAttribute("correlationId"));
        return ResponseEntity.created(URI.create("/api/v1/applications/"+result.applicationId())).body(result);
    }
    @GetMapping("/{id}") @PreAuthorize("hasAnyRole('SELLER','MARKETPLACE_CLIENT','MARKETPLACE_OPERATIONS','ADMIN')")
    public ApplicationView read(@PathVariable String id,@AuthenticationPrincipal Jwt jwt,Authentication auth) {
        boolean admin=auth.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("ROLE_ADMIN"));
        boolean marketplace=auth.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("ROLE_MARKETPLACE_CLIENT")||a.getAuthority().equals("ROLE_MARKETPLACE_OPERATIONS"));
        return service.read(id,jwt,admin,marketplace);
    }
}
