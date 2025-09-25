-- Insert sample data into raw_jobs table
INSERT INTO raw_jobs (
    job_id,
    job_type,
    job_status,
    rate_service_provider,
    total_paid,
    job_date_start,
    job_completed_date,
    job_entered_date,
    job_last_modified_date,
    service_provider_name
) VALUES 
(1001, 'move', 'completed', 'hourly', 285.50, '2024-01-15 08:00:00', '2024-01-15 12:30:00', '2024-01-10 14:22:00', '2024-01-15 13:15:00', 'QuickMover'),
(1002, 'move', 'in_progress', 'fixed_rate', 450.00, '2024-01-16 09:00:00', '', '2024-01-12 16:45:00', '2024-01-16 09:00:00', 'Slow Mover'),
(1003, 'move', 'completed', 'project_based', 1250.75, '2024-01-10 07:00:00', '2024-01-12 18:00:00', '2024-01-08 10:30:00', '2024-01-12 18:30:00', 'Green Mover'),
(1004, 'move', 'scheduled', 'hourly', 0.00, '2024-01-20 10:00:00', '', '2024-01-16 11:15:00', '2024-01-16 11:15:00', 'Scifi Mover'),
(1005, 'cleaning', 'cancelled', 'hourly', 0.00, '2024-01-18 14:00:00', '', '2024-01-14 09:20:00', '2024-01-17 16:45:00', 'QuickMover');
