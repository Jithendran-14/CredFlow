package com.credflow.gateway;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.web.server.SecurityWebFilterChain;
@Configuration public class GatewaySecurity {
    @Bean ReactiveJwtDecoder decoder(@Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}") String issuer,
                                      @Value("${spring.security.oauth2.resourceserver.jwt.jwk-set-uri}") String jwks) {
        var decoder=NimbusReactiveJwtDecoder.withJwkSetUri(jwks).build();
        OAuth2TokenValidator<Jwt> audience=jwt -> jwt.getAudience().contains("credflow-api") ? OAuth2TokenValidatorResult.success() : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token"));
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer(issuer),audience));
        return decoder;
    }
    @Bean SecurityWebFilterChain chain(ServerHttpSecurity http) {
        return http.csrf(ServerHttpSecurity.CsrfSpec::disable).authorizeExchange(a -> a
            .pathMatchers("/actuator/health","/actuator/health/**").permitAll()
            .pathMatchers("/internal/**","/actuator/**").denyAll().anyExchange().authenticated())
            .oauth2ResourceServer(o -> o.jwt(j -> {})).build();
    }
}
