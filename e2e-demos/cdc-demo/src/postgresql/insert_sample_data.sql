-- Sample data for CDC demo
-- Insert 15 loan applications and 15 transactions

-- Loan Applications
INSERT INTO loan_applications (application_id, customer_id, application_date, loan_type, loan_amount_requested, loan_tenure_months, interest_rate_offered, purpose_of_loan, employment_status, monthly_income, cibil_score, existing_emis_monthly, debt_to_income_ratio, property_ownership_status, residential_address, applicant_age, gender, number_of_dependents, loan_status, fraud_flag, fraud_type)
VALUES 
('LA-001', 'CUST001', '2024-01-15', 'Personal Loan', 50000.0, 24, 12.5, 'Medical Emergency', 'Salaried', 45000.0, 720, 5000.0, 11.11, 'Owned', '123 Main Street Mumbai Maharashtra 400001', 32, 'Male', 2, 'Approved', false, NULL),
('LA-002', 'CUST002', '2024-01-16', 'Home Loan', 2500000.0, 240, 8.75, 'Home Purchase', 'Salaried', 95000.0, 780, 15000.0, 15.79, 'Rented', '456 Park Avenue Delhi 110001', 45, 'Female', 3, 'Approved', false, NULL),
('LA-003', 'CUST003', '2024-01-17', 'Car Loan', 800000.0, 60, 10.25, 'Vehicle Purchase', 'Self-Employed', 75000.0, 695, 8000.0, 10.67, 'Owned', '789 Lake Road Bangalore Karnataka 560001', 38, 'Male', 1, 'Approved', false, NULL),
('LA-004', 'CUST004', '2024-01-18', 'Business Loan', 1500000.0, 48, 14.0, 'Business Expansion', 'Self-Employed', 120000.0, 650, 20000.0, 16.67, 'Owned', '321 Industrial Area Chennai Tamil Nadu 600001', 52, 'Male', 4, 'Pending', false, NULL),
('LA-005', 'CUST005', '2024-01-19', 'Education Loan', 400000.0, 84, 9.5, 'Higher Education', 'Unemployed', 0.0, 710, 0.0, 0.0, 'Rented', '654 College Street Kolkata West Bengal 700001', 22, 'Female', 0, 'Approved', false, NULL),
('LA-006', 'CUST006', '2024-01-20', 'Personal Loan', 100000.0, 12, 15.0, 'Debt Consolidation', 'Salaried', 55000.0, 620, 12000.0, 21.82, 'Rented', '987 Office Complex Hyderabad Telangana 500001', 28, 'Male', 1, 'Declined', false, NULL),
('LA-007', 'CUST007', '2024-01-21', 'Home Loan', 3500000.0, 300, 8.5, 'Home Construction', 'Salaried', 150000.0, 810, 25000.0, 16.67, 'Owned', '147 Villa Lane Pune Maharashtra 411001', 40, 'Female', 2, 'Approved', false, NULL),
('LA-008', 'CUST008', '2024-01-22', 'Car Loan', 600000.0, 48, 11.0, 'Vehicle Purchase', 'Salaried', 65000.0, 700, 7000.0, 10.77, 'Rented', '258 Highway Road Ahmedabad Gujarat 380001', 35, 'Male', 2, 'Approved', false, NULL),
('LA-009', 'CUST009', '2024-01-23', 'Business Loan', 2000000.0, 60, 13.5, 'Equipment Purchase', 'Self-Employed', 200000.0, 750, 30000.0, 15.0, 'Owned', '369 Market Street Jaipur Rajasthan 302001', 48, 'Male', 3, 'Approved', false, NULL),
('LA-010', 'CUST010', '2024-01-24', 'Personal Loan', 75000.0, 18, 14.5, 'Wedding Expenses', 'Salaried', 40000.0, 680, 4000.0, 10.0, 'Rented', '741 Apartment Block Lucknow Uttar Pradesh 226001', 30, 'Female', 0, 'Approved', false, NULL),
('LA-011', 'CUST011', '2024-01-25', 'Education Loan', 600000.0, 120, 9.0, 'Study Abroad', 'Unemployed', 0.0, 740, 0.0, 0.0, 'Owned', '852 University Road Chandigarh 160001', 24, 'Male', 0, 'Approved', false, NULL),
('LA-012', 'CUST012', '2024-01-26', 'Home Loan', 4000000.0, 240, 8.25, 'Property Investment', 'Salaried', 180000.0, 820, 35000.0, 19.44, 'Owned', '963 Premium Towers Mumbai Maharashtra 400002', 55, 'Male', 2, 'Approved', false, NULL),
('LA-013', 'CUST013', '2024-01-27', 'Personal Loan', 25000.0, 6, 16.0, 'Emergency Funds', 'Salaried', 30000.0, 590, 3000.0, 10.0, 'Rented', '159 Budget Housing Nagpur Maharashtra 440001', 26, 'Female', 1, 'Declined', true, 'Income Misrepresentation'),
('LA-014', 'CUST014', '2024-01-28', 'Car Loan', 1200000.0, 72, 9.75, 'Luxury Vehicle', 'Self-Employed', 100000.0, 770, 10000.0, 10.0, 'Owned', '357 Elite Colony Delhi 110002', 42, 'Male', 2, 'Approved', false, NULL),
('LA-015', 'CUST015', '2024-01-29', 'Business Loan', 500000.0, 36, 12.0, 'Working Capital', 'Self-Employed', 80000.0, 660, 8000.0, 10.0, 'Rented', '468 Commercial Hub Bangalore Karnataka 560002', 36, 'Female', 1, 'Pending', false, NULL)
ON CONFLICT (application_id) DO NOTHING;

-- Transactions
INSERT INTO transactions (transaction_id, customer_id, transaction_date, transaction_type, transaction_amount, merchant_category, merchant_name, transaction_location, account_balance_after_transaction, is_international_transaction, device_used, ip_address, transaction_status, transaction_source_destination, transaction_notes, fraud_flag)
VALUES 
('TX-001', 'CUST001', '2024-01-15 10:30:00', 'Debit Card', 2500.0, 'Groceries', 'BigMart Superstore', 'Mumbai Maharashtra', 45000.0, false, 'Mobile', '192.168.1.10', 'Success', 'ACC123456789', 'Weekly grocery shopping', false),
('TX-002', 'CUST002', '2024-01-15 14:45:00', 'Credit Card', 15000.0, 'Electronics', 'TechWorld Store', 'Delhi', 85000.0, false, 'Web', '10.0.0.25', 'Success', 'ACC234567890', 'Laptop accessories purchase', false),
('TX-003', 'CUST003', '2024-01-16 09:15:00', 'UPI', 500.0, 'Dining', 'Coffee Corner Cafe', 'Bangalore Karnataka', 32500.0, false, 'Mobile', '172.16.0.50', 'Success', 'ACC345678901', 'Morning coffee', false),
('TX-004', 'CUST004', '2024-01-16 11:00:00', 'Bank Transfer', 50000.0, 'Business', 'Supplier Payments Ltd', 'Chennai Tamil Nadu', 250000.0, false, 'Web', '192.168.10.100', 'Success', 'ACC456789012', 'Vendor payment', false),
('TX-005', 'CUST005', '2024-01-16 16:30:00', 'Debit Card', 1200.0, 'Books', 'Campus Bookstore', 'Kolkata West Bengal', 18000.0, false, 'POS', '10.10.10.10', 'Success', 'ACC567890123', 'Semester textbooks', false),
('TX-006', 'CUST001', '2024-01-17 08:00:00', 'UPI', 350.0, 'Transport', 'Metro Recharge', 'Mumbai Maharashtra', 44650.0, false, 'Mobile', '192.168.1.10', 'Success', 'ACC123456789', 'Monthly metro pass', false),
('TX-007', 'CUST006', '2024-01-17 13:20:00', 'Credit Card', 8500.0, 'Shopping', 'Fashion Hub Mall', 'Hyderabad Telangana', 42000.0, false, 'POS', '172.20.0.15', 'Success', 'ACC678901234', 'Clothing purchase', false),
('TX-008', 'CUST007', '2024-01-17 19:45:00', 'Debit Card', 3200.0, 'Utilities', 'PowerGrid Electricity', 'Pune Maharashtra', 125000.0, false, 'Web', '10.20.30.40', 'Success', 'ACC789012345', 'Electricity bill payment', false),
('TX-009', 'CUST008', '2024-01-18 10:10:00', 'UPI', 750.0, 'Healthcare', 'MedPlus Pharmacy', 'Ahmedabad Gujarat', 28000.0, false, 'Mobile', '192.168.5.25', 'Success', 'ACC890123456', 'Medicine purchase', false),
('TX-010', 'CUST009', '2024-01-18 15:30:00', 'Bank Transfer', 100000.0, 'Business', 'Raw Materials Co', 'Jaipur Rajasthan', 450000.0, false, 'Web', '10.50.100.200', 'Success', 'ACC901234567', 'Inventory purchase', false),
('TX-011', 'CUST010', '2024-01-19 11:45:00', 'Credit Card', 25000.0, 'Travel', 'SkyHigh Airlines', 'Lucknow Uttar Pradesh', 35000.0, true, 'Mobile', '203.0.113.50', 'Success', 'ACC012345678', 'Flight booking international', false),
('TX-012', 'CUST002', '2024-01-19 20:00:00', 'Debit Card', 4500.0, 'Entertainment', 'MovieMax Cinema', 'Delhi', 80500.0, false, 'POS', '10.0.0.25', 'Success', 'ACC234567890', 'Family movie night', false),
('TX-013', 'CUST011', '2024-01-20 09:30:00', 'UPI', 200.0, 'Dining', 'Street Food Corner', 'Chandigarh', 22000.0, false, 'Mobile', '192.168.100.50', 'Success', 'ACC112345678', 'Breakfast', false),
('TX-014', 'CUST003', '2024-01-20 14:15:00', 'Credit Card', 75000.0, 'Shopping', 'Premium Electronics', 'Bangalore Karnataka', 150000.0, false, 'Web', '172.16.0.50', 'Success', 'ACC345678901', 'New smartphone', false),
('TX-015', 'CUST012', '2024-01-20 18:00:00', 'Bank Transfer', 200000.0, 'Investment', 'MutualFund Direct', 'Mumbai Maharashtra', 1200000.0, false, 'Web', '10.100.200.50', 'Success', 'ACC223456789', 'SIP investment', false)
ON CONFLICT (transaction_id) DO NOTHING;

-- Display counts
SELECT 'loan_applications' as table_name, count(*) as row_count FROM loan_applications
UNION ALL
SELECT 'transactions' as table_name, count(*) as row_count FROM transactions;
