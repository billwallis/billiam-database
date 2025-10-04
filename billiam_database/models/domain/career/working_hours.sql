model (
    name career.weekly_working_hours,
    kind full,
    grain (week_starting),
    columns (
        week_starting date,
        weekly_quota decimal(6, 4),
        absence_hours decimal(6, 4),
        expected_working_hours decimal(6, 4),
    ),
    audits (
      not_null(columns=[
        week_starting,
        weekly_quota,
        absence_hours,
        expected_working_hours,
      ]),
      unique_values(columns=[week_starting]),
    ),
);


with recursive

weeks(week_starting) as (
        select date_trunc('week', (select min(from_date) from raw.work_hours))
    union all
        select week_starting + interval '1 week'
        from weeks
        where week_starting < current_date - interval '1 week'
),

weekly_quota as (
    select
        from_date,
        coalesce(to_date, '9999-12-31') as to_date,
        (0
            + sunday
            + monday
            + tuesday
            + wednesday
            + thursday
            + friday
            + saturday
        ) as weekly_quota
    from raw.work_hours
),

absence_hours as (
    select
        date_trunc('week', absence_date) as week_starting,
        sum(hours) as absence_hours
    from raw.work_absences
    group by all
),

all_hours as (
    select
        weeks.week_starting,
        coalesce(weekly_quota.weekly_quota, 0) as weekly_quota,
        coalesce(absence_hours.absence_hours, 0) as absence_hours
    from weeks
        left join weekly_quota
            on weeks.week_starting between weekly_quota.from_date and weekly_quota.to_date
        left join absence_hours
            using (week_starting)
)

select
    week_starting,
    weekly_quota,
    absence_hours,
    weekly_quota - absence_hours as expected_working_hours
from all_hours
order by week_starting
;
