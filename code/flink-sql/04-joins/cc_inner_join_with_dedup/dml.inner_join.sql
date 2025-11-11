

with deduped_AssetTypeAsset as (
    select AssetId, TypeId, Version, ts_ltz
    from (
        select AssetId, TypeId, Version, ts_ltz,
        ROW_NUMBER() OVER (PARTITION BY AssetId, TypeId ORDER BY ts_ltz DESC) as rn
        from `raw_AssetTypeAsset`)
    where rn = 1
),
deduped_AssetType as (
    select id, name, description, ts_ltz
    from (
        select id, name, description, ts_ltz,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY ts_ltz DESC) as rn
        from `raw_AssetType`)
    where rn = 1
)
select 
  deduped_AssetTypeAsset.AssetId,
  deduped_AssetTypeAsset.TypeId,
  deduped_AssetTypeAsset.Version,
  deduped_AssetType.name,
  deduped_AssetType.description
from deduped_AssetTypeAsset
inner join deduped_AssetType on deduped_AssetTypeAsset.TypeId = deduped_AssetType.id
