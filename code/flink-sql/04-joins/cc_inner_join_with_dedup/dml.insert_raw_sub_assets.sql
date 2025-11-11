EXECUTE STATEMENT SET
BEGIN
INSERT INTO raw_AssetSubType (id, name, description, ts_ltz) VALUES
('subtype_001', 'Server-type-1', 'Physical or virtual server hardware', TO_TIMESTAMP_LTZ('2024-01-15 10:00:00', 'yyyy-MM-dd HH:mm:ss')),
('subtype_002', 'Laptop-type-2', 'Physical or virtual server hardware', TO_TIMESTAMP_LTZ('2024-01-15 10:05:00', 'yyyy-MM-dd HH:mm:ss')),
('subtype_003', 'Router-type-3', 'Physical or virtual server hardware', TO_TIMESTAMP_LTZ('2024-01-15 10:10:00', 'yyyy-MM-dd HH:mm:ss'));

INSERT INTO raw_AssetSubTypeAsset (AssetId, SubTypeId, Version, ts_ltz) VALUES
('asset_001', 'subtype_001', 1,TO_TIMESTAMP_LTZ('2024-01-16 09:00:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_002', 'subtype_002', 1, TO_TIMESTAMP_LTZ('2024-01-16 09:15:00', 'yyyy-MM-dd HH:mm:ss')),
('asset_003', 'subtype_003', 1, TO_TIMESTAMP_LTZ('2024-01-16 09:15:00', 'yyyy-MM-dd HH:mm:ss'));

END;