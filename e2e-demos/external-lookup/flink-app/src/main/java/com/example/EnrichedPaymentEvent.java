package com.example;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * Enriched payment event model that includes claim metadata from external lookup.
 * This represents the final output after successful enrichment.
 */
public class EnrichedPaymentEvent {
    // Original payment fields
    public String payment_id;
    public String claim_id;
    public BigDecimal payment_amount;
    public LocalDateTime payment_date;
    public String processor_id;
    public String payment_method;
    public String payment_status;
    public String reference_number;
    public String transaction_id;
    public String notes;
    public String created_by;

    // Enriched fields from claims lookup
    public String member_id;
    public BigDecimal claim_amount;
    public String claim_status;
    public LocalDateTime claim_created_date;

    // Enrichment metadata
    public String enrichment_status;
    public LocalDateTime enrichment_timestamp;
    public String error_message;

    // Default constructor for Flink serialization
    public EnrichedPaymentEvent() {}

    public EnrichedPaymentEvent(PaymentEvent payment) {
        this.payment_id = payment.payment_id;
        this.claim_id = payment.claim_id;
        this.payment_amount = payment.payment_amount;
        this.payment_date = payment.payment_date;
        this.processor_id = payment.processor_id;
        this.payment_method = payment.payment_method;
        this.payment_status = payment.payment_status;
        this.reference_number = payment.reference_number;
        this.transaction_id = payment.transaction_id;
        this.notes = payment.notes;
        this.created_by = payment.created_by;
        this.enrichment_timestamp = LocalDateTime.now();
    }

    // Getters and setters for original payment fields
    public String getPayment_id() { return payment_id; }
    public void setPayment_id(String payment_id) { this.payment_id = payment_id; }

    public String getClaim_id() { return claim_id; }
    public void setClaim_id(String claim_id) { this.claim_id = claim_id; }

    public BigDecimal getPayment_amount() { return payment_amount; }
    public void setPayment_amount(BigDecimal payment_amount) { this.payment_amount = payment_amount; }

    public LocalDateTime getPayment_date() { return payment_date; }
    public void setPayment_date(LocalDateTime payment_date) { this.payment_date = payment_date; }

    public String getProcessor_id() { return processor_id; }
    public void setProcessor_id(String processor_id) { this.processor_id = processor_id; }

    public String getPayment_method() { return payment_method; }
    public void setPayment_method(String payment_method) { this.payment_method = payment_method; }

    public String getPayment_status() { return payment_status; }
    public void setPayment_status(String payment_status) { this.payment_status = payment_status; }

    public String getReference_number() { return reference_number; }
    public void setReference_number(String reference_number) { this.reference_number = reference_number; }

    public String getTransaction_id() { return transaction_id; }
    public void setTransaction_id(String transaction_id) { this.transaction_id = transaction_id; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    public String getCreated_by() { return created_by; }
    public void setCreated_by(String created_by) { this.created_by = created_by; }

    // Getters and setters for enriched fields
    public String getMember_id() { return member_id; }
    public void setMember_id(String member_id) { this.member_id = member_id; }

    public BigDecimal getClaim_amount() { return claim_amount; }
    public void setClaim_amount(BigDecimal claim_amount) { this.claim_amount = claim_amount; }

    public String getClaim_status() { return claim_status; }
    public void setClaim_status(String claim_status) { this.claim_status = claim_status; }

    public LocalDateTime getClaim_created_date() { return claim_created_date; }
    public void setClaim_created_date(LocalDateTime claim_created_date) { this.claim_created_date = claim_created_date; }

    // Getters and setters for enrichment metadata
    public String getEnrichment_status() { return enrichment_status; }
    public void setEnrichment_status(String enrichment_status) { this.enrichment_status = enrichment_status; }

    public LocalDateTime getEnrichment_timestamp() { return enrichment_timestamp; }
    public void setEnrichment_timestamp(LocalDateTime enrichment_timestamp) { this.enrichment_timestamp = enrichment_timestamp; }

    public String getError_message() { return error_message; }
    public void setError_message(String error_message) { this.error_message = error_message; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        EnrichedPaymentEvent that = (EnrichedPaymentEvent) o;
        return Objects.equals(payment_id, that.payment_id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(payment_id);
    }

    @Override
    public String toString() {
        return "EnrichedPaymentEvent{" +
                "payment_id='" + payment_id + '\'' +
                ", claim_id='" + claim_id + '\'' +
                ", payment_amount=" + payment_amount +
                ", member_id='" + member_id + '\'' +
                ", claim_amount=" + claim_amount +
                ", enrichment_status='" + enrichment_status + '\'' +
                ", enrichment_timestamp=" + enrichment_timestamp +
                '}';
    }
}
