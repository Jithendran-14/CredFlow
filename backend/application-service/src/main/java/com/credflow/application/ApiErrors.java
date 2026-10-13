package com.credflow.application;
import jakarta.servlet.http.HttpServletRequest;
import java.util.*;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.*;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;
@RestControllerAdvice public class ApiErrors {
    public record Error(String code,String message,String correlationId,List<Map<String,String>> fieldErrors) {}
    @ExceptionHandler(BusinessException.class) ResponseEntity<Error> business(BusinessException ex,HttpServletRequest request) {
        return ResponseEntity.status(ex.status).body(new Error(ex.code,ex.getMessage(),correlation(request),List.of()));
    }
    @ExceptionHandler(MethodArgumentNotValidException.class) ResponseEntity<Error> validation(MethodArgumentNotValidException ex,HttpServletRequest request) {
        var fields=ex.getBindingResult().getFieldErrors().stream().map(e->Map.of("field",e.getField(),"message",Objects.requireNonNullElse(e.getDefaultMessage(),"Invalid value"))).toList();
        return ResponseEntity.badRequest().body(new Error("VALIDATION_FAILED","Check the supplied fields.",correlation(request),fields));
    }
    @ExceptionHandler(HttpMessageNotReadableException.class) ResponseEntity<Error> malformed(HttpServletRequest request) {
        return ResponseEntity.badRequest().body(new Error("INVALID_JSON","Request fields or JSON are invalid.",correlation(request),List.of()));
    }
    @ExceptionHandler(DataIntegrityViolationException.class) ResponseEntity<Error> conflict(HttpServletRequest request) {
        return ResponseEntity.status(409).body(new Error("REQUEST_CONFLICT","The request conflicts with an existing record. Retry the same idempotency key after concurrent processing completes.",correlation(request),List.of()));
    }
    private static String correlation(HttpServletRequest request) { return (String)request.getAttribute("correlationId"); }
}
