model (
    name raw.finances,
    kind full,
    grain (row_id),
    tags (finances),
    depends_on (
        raw.amex_transactions,
        raw.monzo_transactions,
        raw.counterparty_exclusions,
    ),
    columns (
        row_id int,
        transaction_id int,
        transaction_date date,
        item varchar,
        cost decimal(18, 2),
        category varchar,
        counterparty varchar,
        payment_method varchar,
        exclusion_flag boolean,
        reimbursement_transaction_id int,
    ),
    audits (
        not_null(columns=[
            row_id,
            transaction_id,
            transaction_date,
            item,
            cost,
            category,
            counterparty,
            payment_method,
            exclusion_flag,
        ]),
        unique_values(columns=[row_id]),
        assert__monzo_transactions_reconcile,
        assert__monzo_transactions_reconcile__tfl,
        assert__amex_transactions_reconcile,
    ),
);


from (
        /* Current Finances */
        select *
        from 'billiam_database/models/raw/data/finances.csv'
    union all by name
        /* Historic Finances */
        select *
        from 'billiam_database/models/raw/data/finances-history-*.csv'
)
select
    row_number() over () as row_id,  /* A pseudo row ID for maintaining uniqueness */
    "Transaction"::int as transaction_id,
    "Date"::date as transaction_date,
    trim("Item") as item,
    translate("Cost", '£,', '')::decimal(18, 2) as "cost",
    trim("Category") as category,
    trim("Retailer") as counterparty,
    trim("Payment Method") as payment_method,
    coalesce("Exclusion"::bool, false) as exclusion_flag,
    "Reimbursement Transaction"::int as reimbursement_transaction_id
;


------------------------------------------------------------------------
------------------------------------------------------------------------

audit (name assert__monzo_transactions_reconcile);
with

my_transactions_rollup as (
    select
        transaction_id,
        any_value(transaction_date) as transaction_date,
        any_value(counterparty) as counterparty,
        sum(cost)::decimal(18, 2) as cost,
    from raw.finances
    where 1=1
        and payment_method = 'Monzo'
        and category != 'Interest'
        and counterparty not in ('Monzo Joint', 'TfL')
        /* Specific exceptions */
        and transaction_id not in (
            1132, /* 2019-07-22, £5 Joining Reward */
        )
        /* Monzo changes */
        and if(transaction_date < '2023-11-17', item != 'Monzo Premium', 1=1)
    group by transaction_id
),

my_txns as (
    select
        row_number() over (order by transaction_id) as row_id,

        transaction_id,
        transaction_date,
        counterparty,
        cost,

        (sum(cost) over (order by transaction_id))::decimal(18, 2) as running_cost,
    from my_transactions_rollup
),
monzo_txns as (
    select
        row_number() over (order by transaction_date, transaction_time) as row_id,

        transaction_id,
        transaction_date,
        regexp_replace(replace(counterparty, '’', ''''), ' (Co|Ltd|Limited|Limite)$', '', 'i') as counterparty,
        cost::decimal(18, 2) as cost,

        (sum(cost) over (order by transaction_date, transaction_time))::decimal(18, 2) as running_cost,
    from raw.monzo_transactions
    where "type" not in ('Pot transfer')
      and cost != 0
      and category not in ('Savings')
      and counterparty not in ('Transport for London')
      and counterparty not in (from raw.counterparty_exclusions)
),

joined as (
    select
        row_id,

        my_txns.transaction_date as t_dt,
        my_txns.transaction_id as t_id,
        my_txns.counterparty,
        my_txns.cost,

        monzo_txns.cost as cost__monzo,
        my_txns.running_cost as running_cost__mine,
        monzo_txns.running_cost as running_cost__monzo,

        my_txns.running_cost = monzo_txns.running_cost as match_flag,
        my_txns.running_cost - monzo_txns.running_cost as diff,
    from my_txns
        full join monzo_txns using (row_id)
    order by row_id
)

/* Uncomment for investigating */
-- from joined order by row_id desc;

/*
    For now, we just match "close enough" -- this is because the transactions
    are recorded at different times between the sources _and_ because the
    merchant names are not always consistent, so it's harder to join them
    together with integrity.

    If we've had 20 mismatches in a row, then this audit will fail.
*/
select sum(match_flag::int) as matches
from (
    select *
    from joined
    qualify row_id >= -20 + max(row_id) over ()
)
having matches = 0
;


------------------------------------------------------------------------
------------------------------------------------------------------------

audit (name assert__monzo_transactions_reconcile__tfl);
with

my_txns as (
    select
        transaction_date,
        sum(cost)::numeric(18, 2) as cost,
    from raw.finances
    where (counterparty, payment_method) = ('TfL', 'Monzo')
    group by transaction_date
),
monzo_txns as (
    select
        transaction_date,
        sum(cost)::numeric(18, 2) as cost,
    from raw.monzo_transactions
    where counterparty = 'Transport for London'
      and cost != 0
    group by transaction_date
),

dates(transaction_date) as (
    select dt::date
    from generate_series(
         (select min(transaction_date) from my_txns),
         current_date,
         interval 1 day
    ) as gs(dt)
),

joined as (
    from (
        select
            transaction_date,
            coalesce(my_txns.cost, 0) as cost__mine,
            coalesce(monzo_txns.cost, 0) as cost__monzo,

            sum(cost__mine)  over t_date as running_cost__mine,
            sum(cost__monzo) over t_date as running_cost__monzo,
        from dates
            left join my_txns    using (transaction_date)
            left join monzo_txns using (transaction_date)
        window t_date as (order by transaction_date)
    )
    select
        row_number() over (order by transaction_date) as row_id,
        transaction_date,
        cost__mine,
        cost__monzo,
        running_cost__mine,
        running_cost__monzo,
        (0=1
            or running_cost__mine = running_cost__monzo
            /* account for the regular 1-day lag */
            or running_cost__mine = lead(running_cost__monzo) over (order by transaction_date)
        ) as match_flag,
)

/* Uncomment for investigating */
-- from joined order by transaction_date desc;

/*
    Similar to the above, we just match "close enough".

    Remember that my spreadsheet (`raw.finances`) records each _journey_,
    whereas Monzo (`raw.monzo_transactions`) records each _transaction_
    which can correspond to several journeys.
*/
select sum(match_flag::int) as matches
from (
    select *
    from joined
    qualify row_id >= -20 + max(row_id) over ()
)
having matches = 0
;


------------------------------------------------------------------------
------------------------------------------------------------------------

audit (name assert__amex_transactions_reconcile);
with

my_transactions_rollup as (
    select
        transaction_id,
        any_value(transaction_date) as transaction_date,
        any_value(counterparty) as counterparty,
        sum(cost)::decimal(18, 2) as cost,
    from raw.finances
    where 1=1
        and payment_method = 'Amex'
        and counterparty not in ('Monzo', 'TfL')
        and not exists(
            /* Remove cancelled Uber requests */
            select *
            from raw.finances as i
            where 1=1
                and finances.counterparty = 'Uber'
                and i.counterparty = 'Uber'
                and finances.transaction_date = i.transaction_date
                and finances.cost = -i.cost
        )
        and transaction_date <= (
            select max(transaction_date)
            from raw.amex_transactions
        )
    group by transaction_id
),

my_txns as (
    select
        row_number() over (order by transaction_id) as row_id,

        transaction_id,
        transaction_date,
        counterparty,
        cost,

        (sum(cost) over (order by transaction_id))::decimal(18, 2) as running_cost,
    from (
        /* Some temporary fixes while I sort out my receipts */
        select
            * replace (
                case transaction_id
                    when 5334 then 25.43  /* WTF is this? */
                    when 5644 then 35.91  /* Check Deliveroo receipt */
                    when 5687 then 50.57  /* Check Deliveroo receipt */
                              else cost
                end as cost
            )
        from my_transactions_rollup
    )
),
amex_txns as (
    select
        row_number() over (order by transaction_date, transaction_id) as row_id,

        transaction_id,
        transaction_date,
        cost::decimal(18, 2) as cost,

        (sum(cost) over (order by transaction_date, transaction_id))::decimal(18, 2) as running_cost,
    from raw.amex_transactions
    where 1=1
        and description not in (
            'PAYMENT RECEIVED - THANK YOU',
            'TFL TRAVEL CHARGE       TFL.GOV.UK/CP'
        )
        and transaction_date <= (
            select max(transaction_date)
            from raw.finances
        )
),

joined as (
    select
        row_id,

        my_txns.transaction_date as t_dt,
        my_txns.transaction_id as t_id,
        my_txns.counterparty,
        my_txns.cost,

        amex_txns.cost as cost__amex,
        my_txns.running_cost as running_cost__mine,
        amex_txns.running_cost as running_cost__amex,

        my_txns.running_cost = amex_txns.running_cost as match_flag,
        my_txns.running_cost - amex_txns.running_cost as diff,
    from my_txns
        full join amex_txns using (row_id)
    order by row_id
)

/* Uncomment for investigating */
-- from joined order by row_id desc;

/*
    Similar to the above, we just match "close enough".
*/
select sum(match_flag::int) as matches
from (
    select *
    from joined
    qualify row_id >= -20 + max(row_id) over ()
)
having matches = 0
;
