package com.credflow.application;
public record ApplicationView(String applicationId,String applicationReference,String sellerId,
    String marketplaceId,String requestedAmount,String currency,String loanPurpose,String status,
    int applicationRevision,int version,int workflowVersion) {}
