package com.credflow.platform;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.core.Ordered;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.bind.annotation.*;
@Configuration @EnableMethodSecurity
public class PlatformConfiguration {
    @Bean JwtDecoder jwtDecoder(@Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}") String issuer,
                                @Value("${spring.security.oauth2.resourceserver.jwt.jwk-set-uri}") String jwks,
                                @Value("${credflow.security.audience}") String audience) {
        var decoder=NimbusJwtDecoder.withJwkSetUri(jwks).build();
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer(issuer),new AudienceValidator(audience)));
        return decoder;
    }
    @Bean SecurityFilterChain security(HttpSecurity http) throws Exception {
        var converter=new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            Object access=jwt.getClaims().get("realm_access");
            if(!(access instanceof Map<?,?> map) || !(map.get("roles") instanceof Collection<?> roles)) return List.of();
            return roles.stream().filter(String.class::isInstance).<org.springframework.security.core.GrantedAuthority>map(r -> new SimpleGrantedAuthority("ROLE_"+r)).toList();
        });
        return http.csrf(csrf -> csrf.disable()).sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(a -> a.requestMatchers(HttpMethod.GET,"/actuator/health","/actuator/health/**").permitAll()
                .requestMatchers("/actuator/**").hasRole("ADMIN").anyRequest().authenticated())
            .oauth2ResourceServer(o -> o.jwt(j -> j.jwtAuthenticationConverter(converter))).build();
    }
    @Bean FilterRegistrationBean<CorrelationFilter> correlationFilter() {
        var registration=new FilterRegistrationBean<>(new CorrelationFilter()); registration.setOrder(Ordered.HIGHEST_PRECEDENCE); return registration;
    }
    @RestController public static class FoundationController {
        private final String name;
        public FoundationController(@Value("${spring.application.name}") String name) { this.name=name; }
        @GetMapping("/api/v1/system/{service}/info") public Map<String,String> info(@PathVariable String service) {
            if(!name.equals(service)) throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND);
            return Map.of("service",name,"stage","FOUNDATION");
        }
    }
}
