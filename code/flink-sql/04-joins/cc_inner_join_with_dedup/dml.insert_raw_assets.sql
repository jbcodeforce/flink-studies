EXECUTE STATEMENT SET
BEGIN
INSERT INTO raw_AssetType (id, name, description, ts_ltz) VALUES
('type_001', 'Server', 'Physical or virtual server hardware', TO_TIMESTAMP_LTZ('2024-01-15 10:00:00', 'yyyy-MM-dd HH:mm:ss')),
('type_002', 'Laptop', 'Portable computer for employees', TO_TIMESTAMP_LTZ('2024-01-15 10:05:00', 'yyyy-MM-dd HH:mm:ss')),
('type_003', 'Router', 'Network routing device', TO_TIMESTAMP_LTZ('2024-01-15 10:10:00', 'yyyy-MM-dd HH:mm:ss')),
('type_004', 'Switch', 'Network switching device', TO_TIMESTAMP_LTZ('2024-01-15 10:15:00', 'yyyy-MM-dd HH:mm:ss')),
('type_005', 'Phone', 'Mobile or desk phone', TO_TIMESTAMP_LTZ('2024-01-15 10:20:00', 'yyyy-MM-dd HH:mm:ss')),
('type_006', 'Tablet', 'Tablet device', TO_TIMESTAMP_LTZ('2024-01-15 10:25:00', 'yyyy-MM-dd HH:mm:ss')),
('type_007', 'Monitor', 'Display monitor', TO_TIMESTAMP_LTZ('2024-01-15 10:30:00', 'yyyy-MM-dd HH:mm:ss')),
('type_008', 'Printer', 'Printing device', TO_TIMESTAMP_LTZ('2024-01-15 10:35:00', 'yyyy-MM-dd HH:mm:ss')),
('type_009', 'Scanner', 'Document scanning device', TO_TIMESTAMP_LTZ('2024-01-15 10:40:00', 'yyyy-MM-dd HH:mm:ss')),
('type_009', 'Scanner', 'Document scanning device2', TO_TIMESTAMP_LTZ('2024-01-15 10:40:00', 'yyyy-MM-dd HH:mm:ss')),
('type_010', 'Firewall', 'Network security device', TO_TIMESTAMP_LTZ('2024-01-15 10:45:00', 'yyyy-MM-dd HH:mm:ss'));

INSERT INTO raw_AssetTypeAsset (AssetId, TypeId, Version, ts_ltz) VALUES
('asset_001', 'type_001', 1,TO_TIMESTAMP_LTZ('2024-01-16 09:00:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_002', 'type_002', 1, TO_TIMESTAMP_LTZ('2024-01-16 09:15:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_003', 'type_003', 1, TO_TIMESTAMP_LTZ('2024-01-16 09:30:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_004', 'type_001', 1, TO_TIMESTAMP_LTZ('2024-01-16 09:45:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_005', 'type_005', 1, TO_TIMESTAMP_LTZ('2024-01-16 10:00:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_006', 'type_002', 1, TO_TIMESTAMP_LTZ('2024-01-16 10:15:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_007', 'type_007', 1, TO_TIMESTAMP_LTZ('2024-01-16 10:30:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_008', 'type_008', 1, TO_TIMESTAMP_LTZ('2024-01-16 10:45:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_009', 'type_010', 1, TO_TIMESTAMP_LTZ('2024-01-16 11:00:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_009', 'type_010', 2, TO_TIMESTAMP_LTZ('2024-01-16 11:00:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_010', 'type_004', 1, TO_TIMESTAMP_LTZ('2024-01-16 11:15:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_011', 'type_009', 1, TO_TIMESTAMP_LTZ('2024-01-16 11:16:00', 'yyyy-MM-dd HH:mm:ss'));

END;