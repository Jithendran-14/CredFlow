package com.credflow.application;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.*;
import java.util.UUID;
public record ApplicationRequest(
    @NotNull UUID marketplaceId,
    @NotBlank @Size(max=100) String marketplaceSellerId,
    @NotBlank @Size(max=100) String marketplaceRequestId,
    @NotBlank @Pattern(regexp="[0-9]{1,17}\\.[0-9]{2}") String requestedAmount,
    @NotNull Currency currency,
    @NotNull LoanPurpose loanPurpose,
    @NotNull @Valid BusinessProfile businessProfile,
    @NotBlank @Size(max=100) String sellerRequestReference,
    @NotNull @Valid InitialSharingConsent initialSharingConsent) {
    public enum Currency { INR }
    public enum LoanPurpose { PURCHASE_INVENTORY, WORKING_CAPITAL, BUSINESS_EXPANSION }
    public record BusinessProfile(@NotBlank @Size(max=100) String displayName,
        @NotBlank @Size(max=200) String businessName,@NotNull @PastOrPresent LocalDate businessStartDate) {}
    public record InitialSharingConsent(@NotBlank @Pattern(regexp="APPLICATION_SHARE_WITH_CREDFLOW") String scope,
        @NotBlank @Size(max=30) String noticeVersion,@NotNull @PastOrPresent Instant authorisedAt,
        @NotBlank @Size(max=100) String evidenceReference) {}
}
