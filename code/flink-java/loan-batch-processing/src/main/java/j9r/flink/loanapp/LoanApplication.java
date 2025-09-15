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
        String[] fields = csvLine.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)"); // Handle commas within quoted fields
        
        try {
            return new LoanApplication(
                fields[0], // application_id
                fields[1], // customer_id
                fields[2], // application_date
                fields[3], // loan_type
                parseDouble(fields[4]), // loan_amount_requested
                parseInt(fields[5]), // loan_tenure_months
                parseDouble(fields[6]), // interest_rate_offered
                fields[7], // purpose_of_loan
                fields[8], // employment_status
                parseDouble(fields[9]), // monthly_income
                parseInt(fields[10]), // cibil_score
                parseDouble(fields[11]), // existing_emis_monthly
                parseDouble(fields[12]), // debt_to_income_ratio
                fields[13], // property_ownership_status
                fields[14], // residential_address
                parseInt(fields[15]), // applicant_age
                fields[16], // gender
                parseInt(fields[17]), // number_of_dependents
                fields[18], // loan_status
                parseInt(fields[19]), // fraud_flag
                fields.length > 20 ? fields[20] : "" // fraud_type (can be empty)
            );
        } catch (Exception e) {
            System.err.println("Error parsing CSV line: " + csvLine);
            e.printStackTrace();
            return null;
        }
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
