-- External Lookup Demo - Sample Claims Data
-- This script inserts sample claims data for testing various lookup scenarios

-- Clear existing data (for clean test runs)
DELETE FROM claims;

-- Insert sample claims data covering various test scenarios
INSERT INTO claims (claim_id, member_id, claim_amount, claim_status, claim_type, created_date, policy_number, provider_id, diagnosis_code) VALUES
-- Valid claims for successful lookup testing
('CLM-001', 'MBR-12345', 1250.50, 'APPROVED', 'MEDICAL', '2024-01-15 10:30:00', 'POL-98765', 'PRV-101', 'Z23.1'),
('CLM-002', 'MBR-12346', 875.25, 'PENDING', 'DENTAL', '2024-01-16 14:15:00', 'POL-98766', 'PRV-102', 'K02.9'),
('CLM-003', 'MBR-12347', 2100.00, 'APPROVED', 'MEDICAL', '2024-01-17 09:45:00', 'POL-98767', 'PRV-103', 'M79.3'),
('CLM-004', 'MBR-12348', 450.75, 'PROCESSING', 'VISION', '2024-01-18 16:20:00', 'POL-98768', 'PRV-104', 'H52.4'),
('CLM-005', 'MBR-12349', 5500.00, 'APPROVED', 'MEDICAL', '2024-01-19 11:10:00', 'POL-98769', 'PRV-105', 'I21.9'),

-- More valid claims for load testing
('CLM-006', 'MBR-12350', 325.80, 'APPROVED', 'DENTAL', '2024-01-20 13:25:00', 'POL-98770', 'PRV-106', 'K04.7'),
('CLM-007', 'MBR-12351', 1800.00, 'PENDING', 'MEDICAL', '2024-01-21 08:30:00', 'POL-98771', 'PRV-107', 'S72.001A'),
('CLM-008', 'MBR-12352', 250.00, 'APPROVED', 'VISION', '2024-01-22 15:45:00', 'POL-98772', 'PRV-108', 'H25.9'),
('CLM-009', 'MBR-12353', 12000.00, 'PROCESSING', 'LIFE', '2024-01-23 10:15:00', 'POL-98773', 'PRV-109', 'Z51.11'),
('CLM-010', 'MBR-12354', 3200.50, 'APPROVED', 'DISABILITY', '2024-01-24 12:40:00', 'POL-98774', 'PRV-110', 'M54.5'),

-- Claims with denied status (for testing filtering)
('CLM-011', 'MBR-12355', 750.00, 'DENIED', 'MEDICAL', '2024-01-25 09:20:00', 'POL-98775', 'PRV-111', 'Z99.89'),
('CLM-012', 'MBR-12356', 425.30, 'DENIED', 'DENTAL', '2024-01-26 14:55:00', 'POL-98776', 'PRV-112', 'K08.9'),

-- High-value claims for edge case testing
('CLM-013', 'MBR-12357', 25000.00, 'PENDING', 'MEDICAL', '2024-01-27 11:30:00', 'POL-98777', 'PRV-113', 'C78.00'),
('CLM-014', 'MBR-12358', 50000.00, 'APPROVED', 'LIFE', '2024-01-28 16:10:00', 'POL-98778', 'PRV-114', 'Z51.12'),

-- Claims with same member (for testing member aggregation)
('CLM-015', 'MBR-12345', 680.25, 'APPROVED', 'VISION', '2024-01-29 10:05:00', 'POL-98765', 'PRV-115', 'H40.9'),
('CLM-016', 'MBR-12345', 1100.75, 'PENDING', 'DENTAL', '2024-01-30 13:15:00', 'POL-98765', 'PRV-116', 'K07.4'),

-- Recent claims for time-based testing
('CLM-017', 'MBR-12359', 892.40, 'PROCESSING', 'MEDICAL', CURRENT_TIMESTAMP, 'POL-98779', 'PRV-117', 'J44.1'),
('CLM-018', 'MBR-12360', 156.90, 'APPROVED', 'VISION', CURRENT_TIMESTAMP, 'POL-98780', 'PRV-118', 'H57.9'),

-- Claims with null optional fields (for robustness testing)  
('CLM-019', 'MBR-12361', 445.60, 'APPROVED', 'MEDICAL', '2024-02-01 14:30:00', 'POL-98781', NULL, 'R50.9'),
('CLM-020', 'MBR-12362', 275.15, 'PENDING', 'DENTAL', '2024-02-02 09:45:00', NULL, 'PRV-119', 'K02.51');

-- Insert summary statistics for validation
INSERT INTO claims (claim_id, member_id, claim_amount, claim_status, claim_type, created_date, policy_number, provider_id, diagnosis_code) VALUES
-- Edge case: minimum amount
('CLM-MIN', 'MBR-MIN', 0.01, 'APPROVED', 'VISION', '2024-02-03 10:00:00', 'POL-MIN', 'PRV-MIN', 'H99.9'),
-- Edge case: exactly $10,000 (common threshold)
('CLM-10K', 'MBR-10K', 10000.00, 'PROCESSING', 'MEDICAL', '2024-02-04 15:30:00', 'POL-10K', 'PRV-10K', 'Z99.9');

-- Create some test data specifically for payment event correlation
-- These claim IDs will be used in payment event generation
INSERT INTO claims (claim_id, member_id, claim_amount, claim_status, claim_type, created_date, policy_number, provider_id, diagnosis_code) VALUES
('CLAIM-TEST-001', 'MEMBER-001', 1500.00, 'APPROVED', 'MEDICAL', '2024-02-05 08:00:00', 'POLICY-001', 'PROVIDER-001', 'A00.0'),
('CLAIM-TEST-002', 'MEMBER-002', 750.50, 'APPROVED', 'DENTAL', '2024-02-05 09:00:00', 'POLICY-002', 'PROVIDER-002', 'B00.0'),
('CLAIM-TEST-003', 'MEMBER-003', 2250.75, 'PROCESSING', 'MEDICAL', '2024-02-05 10:00:00', 'POLICY-003', 'PROVIDER-003', 'C00.0'),
('CLAIM-TEST-004', 'MEMBER-004', 425.25, 'APPROVED', 'VISION', '2024-02-05 11:00:00', 'POLICY-004', 'PROVIDER-004', 'D00.0'),
('CLAIM-TEST-005', 'MEMBER-005', 8750.00, 'PENDING', 'LIFE', '2024-02-05 12:00:00', 'POLICY-005', 'PROVIDER-005', 'E00.0');

-- Note: claim IDs NOT in this table:
-- CLAIM-INVALID-001, CLAIM-INVALID-002, CLAIM-MISSING-001
-- These will be used to test lookup failure scenarios
