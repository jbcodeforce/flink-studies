package j9r.flink.loanapp;

import java.time.LocalDate;

/**
 * POJO class representing a loan application record from CSV
 */
public class LoanApplication {
    public String applicationId;
    public String customerId;
    public String applicationDate;
    public String loanType;
    public Double loanAmountRequested;
    public Integer loanTenureMonths;
    public Double interestRateOffered;
    public String purposeOfLoan;
    public String employmentStatus;
    public Double monthlyIncome;
    public Integer cibilScore;
    public Double existingEmisMonthly;
    public Double debtToIncomeRatio;
    public String propertyOwnershipStatus;
    public String residentialAddress;
    public Integer applicantAge;
    public String gender;
    public Integer numberOfDependents;
    public String loanStatus;
    public Integer fraudFlag;
    public String fraudType;

    // Default constructor
    public LoanApplication() {}

    // Constructor with all fields
    public LoanApplication(String applicationId, String customerId, String applicationDate,
                          String loanType, Double loanAmountRequested, Integer loanTenureMonths,
                          Double interestRateOffered, String purposeOfLoan, String employmentStatus,
                          Double monthlyIncome, Integer cibilScore, Double existingEmisMonthly,
                          Double debtToIncomeRatio, String propertyOwnershipStatus, String residentialAddress,
                          Integer applicantAge, String gender, Integer numberOfDependents,
                          String loanStatus, Integer fraudFlag, String fraudType) {
        this.applicationId = applicationId;
        this.customerId = customerId;
        this.applicationDate = applicationDate;
        this.loanType = loanType;
        this.loanAmountRequested = loanAmountRequested;
        this.loanTenureMonths = loanTenureMonths;
        this.interestRateOffered = interestRateOffered;
        this.purposeOfLoan = purposeOfLoan;
        this.employmentStatus = employmentStatus;
        this.monthlyIncome = monthlyIncome;
        this.cibilScore = cibilScore;
        this.existingEmisMonthly = existingEmisMonthly;
        this.debtToIncomeRatio = debtToIncomeRatio;
        this.propertyOwnershipStatus = propertyOwnershipStatus;
        this.residentialAddress = residentialAddress;
        this.applicantAge = applicantAge;
        this.gender = gender;
        this.numberOfDependents = numberOfDependents;
        this.loanStatus = loanStatus;
        this.fraudFlag = fraudFlag;
        this.fraudType = fraudType;
    }

    @Override
    public String toString() {
        return "LoanApplication{" +
                "applicationId='" + applicationId + '\'' +
                ", customerId='" + customerId + '\'' +
                ", loanType='" + loanType + '\'' +
                ", loanAmountRequested=" + loanAmountRequested +
                ", loanStatus='" + loanStatus + '\'' +
                ", fraudFlag='" + fraudFlag + '\'' +
                ", fraudType='" + fraudType + '\'' +
                '}';
    }

    // Static method to parse CSV line to LoanApplication object
    public static LoanApplication fromCsvLine(String csvLine) {
        java.util.List<String> fields = parseCSVLine(csvLine);
        
        try {
            return new LoanApplication(
                fields.get(0), // application_id
                fields.get(1), // customer_id
                fields.get(2), // application_date
                fields.get(3), // loan_type
                parseDouble(fields.get(4)), // loan_amount_requested
                parseInt(fields.get(5)), // loan_tenure_months
                parseDouble(fields.get(6)), // interest_rate_offered
                fields.get(7), // purpose_of_loan
                fields.get(8), // employment_status
                parseDouble(fields.get(9)), // monthly_income
                parseInt(fields.get(10)), // cibil_score
                parseDouble(fields.get(11)), // existing_emis_monthly
                parseDouble(fields.get(12)), // debt_to_income_ratio
                fields.get(13), // property_ownership_status
                cleanQuotedField(fields.get(14)), // residential_address (remove quotes)
                parseInt(fields.get(15)), // applicant_age
                fields.get(16), // gender
                parseInt(fields.get(17)), // number_of_dependents
                fields.get(18), // loan_status
                parseInt(fields.get(19)), // fraud_flag (0-indexed position 19)
                fields.size() > 20 ? cleanQuotedField(fields.get(20)) : "" // fraud_type (can be empty)
            );
        } catch (Exception e) {
            System.err.println("Error parsing CSV line: " + csvLine);
            System.err.println("Field count: " + fields.size());
            if (fields.size() > 19) {
                System.err.println("fraud_flag field: " + fields.get(19));
            }
            e.printStackTrace();
            return null;
        }
    }

    // Proper CSV parsing that handles quoted fields with commas
    private static java.util.List<String> parseCSVLine(String csvLine) {
        java.util.List<String> fields = new java.util.ArrayList<>();
        boolean inQuotes = false;
        StringBuilder currentField = new StringBuilder();
        
        for (int i = 0; i < csvLine.length(); i++) {
            char c = csvLine.charAt(i);
            
            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                fields.add(currentField.toString());
                currentField = new StringBuilder();
            } else {
                currentField.append(c);
            }
        }
        
        // Add the last field
        fields.add(currentField.toString());
        
        return fields;
    }
    
    // Helper method to clean quoted fields
    private static String cleanQuotedField(String field) {
        if (field.startsWith("\"") && field.endsWith("\"")) {
            return field.substring(1, field.length() - 1);
        }
        return field;
    }

    private static Double parseDouble(String value) {
        if (value == null || value.trim().isEmpty()) {
            return 0.0;
        }
        try {
            return Double.parseDouble(value);
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    private static Integer parseInt(String value) {
        if (value == null || value.trim().isEmpty()) {
            return 0;
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
