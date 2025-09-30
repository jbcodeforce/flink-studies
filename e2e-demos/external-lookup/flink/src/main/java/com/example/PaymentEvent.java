package com.example;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * Payment event model representing incoming payment transactions.
 * This matches the schema from the event generator.
 */
public class PaymentEvent {
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

    // Default constructor for Flink serialization
    public PaymentEvent() {}

    public PaymentEvent(String payment_id, String claim_id, BigDecimal payment_amount, 
                       LocalDateTime payment_date, String processor_id) {
        this.payment_id = payment_id;
        this.claim_id = claim_id;
        this.payment_amount = payment_amount;
        this.payment_date = payment_date;
        this.processor_id = processor_id;
    }

    // Getters and setters
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

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        PaymentEvent that = (PaymentEvent) o;
        return Objects.equals(payment_id, that.payment_id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(payment_id);
    }

    @Override
    public String toString() {
        return "PaymentEvent{" +
                "payment_id='" + payment_id + '\'' +
                ", claim_id='" + claim_id + '\'' +
                ", payment_amount=" + payment_amount +
                ", payment_date=" + payment_date +
                ", processor_id='" + processor_id + '\'' +
                ", payment_method='" + payment_method + '\'' +
                ", payment_status='" + payment_status + '\'' +
                '}';
    }
}
