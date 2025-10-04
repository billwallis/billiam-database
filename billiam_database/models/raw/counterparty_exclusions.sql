model (
    name raw.counterparty_exclusions,
    kind full,
    grain (counterparty),
    tags (finances),
    columns (
      counterparty varchar,
    ),
);

select *
from ods.finances.counterparty_exclusions
;
