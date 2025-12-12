 with direct_persons as (
    select group_name, item_name as person_name from `group_hierarchy` where item_type = 'PERSON'
    ),

    subgroup_members as (select
        parent.group_name as group_name,
        child.item_name as person_name
        from `group_hierarchy` parent left join `group_hierarchy` child on parent.item_name = child.group_name
        where parent.item_type = 'GROUP' and child.item_type = 'PERSON'
    ),

    all_persons as ( 
        select group_name, person_name from direct_persons
        union all
        select group_name, person_name from subgroup_members
    )
    select
        group_name,
        ARRAY_AGG(person_name) as persons
    from all_persons group by group_name