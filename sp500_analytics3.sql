SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='sp500_index_prices'
ORDER BY ordinal_position;

SELECT
    trade_date,
    close_price,
    LAG(close_price) OVER (ORDER BY trade_date) AS prev_close,
    ROUND(
      (close_price - LAG(close_price) OVER (ORDER BY trade_date))
      / LAG(close_price) OVER (ORDER BY trade_date) * 100, 
    2) AS daily_return_pct
FROM sp500_index_prices
ORDER BY trade_date
LIMIT 15;

WITH daily_returns AS (
    SELECT
        trade_date,
        ROUND(
          (close_price - LAG(close_price) OVER (ORDER BY trade_date))
          / LAG(close_price) OVER (ORDER BY trade_date) * 100, 
        2) AS daily_return_pct
    FROM sp500_index_prices
)
SELECT
    DATE_TRUNC('month', trade_date)::date AS month_start,
    ROUND(AVG(daily_return_pct), 2) AS avg_monthly_return_pct,
    ROUND(SUM(daily_return_pct), 2) AS cum_monthly_return_pct
FROM daily_returns
WHERE daily_return_pct IS NOT NULL
GROUP BY DATE_TRUNC('month', trade_date)
ORDER BY month_start;

WITH daily_returns AS (
    SELECT
        trade_date,
        ROUND(
          (close_price - LAG(close_price) OVER (ORDER BY trade_date))
          / LAG(close_price) OVER (ORDER BY trade_date) * 100, 
        2) AS daily_return_pct
    FROM sp500_index_prices
)
SELECT
    DATE_TRUNC('month', trade_date)::date AS month_start,
    ROUND(AVG(daily_return_pct), 2) AS avg_monthly_return_pct,
    ROUND(SUM(daily_return_pct), 2) AS cum_monthly_return_pct,
    ROUND(STDDEV(daily_return_pct), 2) AS monthly_volatility_pct
FROM daily_returns
WHERE daily_return_pct IS NOT NULL
GROUP BY DATE_TRUNC('month', trade_date)
ORDER BY month_start;

WITH daily_returns AS (
    SELECT
        trade_date,
        DATE_TRUNC('month', trade_date)::date AS month_start,
        (close_price - LAG(close_price) OVER (ORDER BY trade_date))
            / LAG(close_price) OVER (ORDER BY trade_date) * 100 AS daily_return_pct
    FROM sp500_index_prices
),

monthly_stats AS (
    SELECT
        month_start,
        ROUND(SUM(daily_return_pct), 2) AS cum_monthly_return_pct,
        ROUND(STDDEV(daily_return_pct), 2) AS monthly_volatility_pct
    FROM daily_returns
    WHERE daily_return_pct IS NOT NULL
    GROUP BY month_start
)

SELECT
    month_start,
    cum_monthly_return_pct,
    monthly_volatility_pct,
    RANK() OVER (ORDER BY cum_monthly_return_pct DESC) AS return_rank,
    RANK() OVER (ORDER BY monthly_volatility_pct DESC) AS volatility_rank
FROM monthly_stats
ORDER BY month_start;

WITH sector_summary AS (
    SELECT
        sector,
        SUM(market_cap) AS total_market_cap,
        ROUND(AVG(price_earnings)::numeric, 2) AS avg_pe,
        ROUND(AVG(dividend_yield)::numeric, 2) AS avg_dividend
    FROM companies_financials
    GROUP BY sector
),

daily_returns AS (
    SELECT
        trade_date,
        (close_price - LAG(close_price) OVER (ORDER BY trade_date))
        / LAG(close_price) OVER (ORDER BY trade_date) * 100 AS daily_return
    FROM sp500_index_prices
),

index_monthly AS (
    SELECT
        DATE_TRUNC('month', trade_date)::date AS month_start,
        ROUND(SUM(daily_return), 2) AS monthly_return
    FROM daily_returns
    WHERE daily_return IS NOT NULL
    GROUP BY DATE_TRUNC('month', trade_date)
)

SELECT
    s.sector,
    s.total_market_cap,
    s.avg_pe,
    s.avg_dividend,
    i.month_start,
    i.monthly_return
FROM sector_summary s
CROSS JOIN index_monthly i
ORDER BY i.month_start, s.total_market_cap DESC;

WITH index_perf AS (
    SELECT
        DATE_TRUNC('month', trade_date) AS month_start,
        ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) AS monthly_return
    FROM sp500_index_prices
    GROUP BY DATE_TRUNC('month', trade_date)
)
SELECT
    month_start,
    monthly_return,
    CASE
        WHEN monthly_return > 2 THEN 'Bull Month'
        WHEN monthly_return < -2 THEN 'Bear Month'
        ELSE 'Flat Month'
    END AS market_regime
FROM index_perf
ORDER BY month_start;

WITH index_perf AS (
    SELECT
        DATE_TRUNC('month', trade_date) AS month_start,
        ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) AS monthly_return,
        CASE
            WHEN ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) > 2 THEN 'Bull'
            WHEN ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) < -2 THEN 'Bear'
            ELSE 'Flat'
        END AS market_regime
    FROM sp500_index_prices
    GROUP BY DATE_TRUNC('month', trade_date)
)
SELECT
    i.market_regime,
    s.sector,
    ROUND(AVG(s.price_earnings)::numeric, 2) AS avg_pe_ratio,
    ROUND(AVG(s.dividend_yield)::numeric, 2) AS avg_dividend_yield,
    ROUND(SUM(s.market_cap)::numeric, 2) AS total_market_cap
FROM companies_financials s
CROSS JOIN index_perf i
GROUP BY i.market_regime, s.sector
ORDER BY i.market_regime, total_market_cap DESC;

WITH index_perf AS (
    SELECT
        DATE_TRUNC('month', trade_date) AS month_start,
        ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) AS monthly_return,
        CASE
            WHEN ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) > 1 THEN 'Bull'
            WHEN ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) < -1 THEN 'Bear'
            ELSE 'Flat'
        END AS market_regime
    FROM sp500_index_prices
    GROUP BY DATE_TRUNC('month', trade_date)
)
SELECT
    month_start,
    monthly_return,
    market_regime
FROM index_perf
ORDER BY month_start;

SELECT
    DATE_TRUNC('month', trade_date) AS month_start,
    ROUND(((MAX(close_price) - MIN(close_price)) / MIN(close_price)) * 100, 2) AS monthly_return
FROM sp500_index_prices
GROUP BY DATE_TRUNC('month', trade_date)
ORDER BY month_start;

SELECT
    DATE_TRUNC('year', trade_date) AS year_start,
    ROUND(FIRST_VALUE(close_price) OVER (
        PARTITION BY DATE_TRUNC('year', trade_date) 
        ORDER BY trade_date
    )::numeric, 2) AS year_open,
    ROUND(LAST_VALUE(close_price) OVER (
        PARTITION BY DATE_TRUNC('year', trade_date) 
        ORDER BY trade_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )::numeric, 2) AS year_close,
    ROUND(
        (LAST_VALUE(close_price) OVER (
            PARTITION BY DATE_TRUNC('year', trade_date) 
            ORDER BY trade_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) - FIRST_VALUE(close_price) OVER (
            PARTITION BY DATE_TRUNC('year', trade_date) 
            ORDER BY trade_date
        )) / FIRST_VALUE(close_price) OVER (
            PARTITION BY DATE_TRUNC('year', trade_date) 
            ORDER BY trade_date
        ) * 100
    , 2) AS yearly_return_pct
FROM sp500_index_prices
GROUP BY DATE_TRUNC('year', trade_date), trade_date, close_price
ORDER BY year_start;

WITH yearly_stats AS (
    SELECT
        DATE_TRUNC('year', trade_date) AS year_start,
        FIRST_VALUE(close_price) OVER (
            PARTITION BY DATE_TRUNC('year', trade_date) 
            ORDER BY trade_date
        ) AS year_open,
        LAST_VALUE(close_price) OVER (
            PARTITION BY DATE_TRUNC('year', trade_date) 
            ORDER BY trade_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS year_close
    FROM sp500_index_prices
)
SELECT DISTINCT
    year_start,
    ROUND(year_open::numeric, 2) AS year_open,
    ROUND(year_close::numeric, 2) AS year_close,
    ROUND(((year_close - year_open) / year_open) * 100, 2) AS yearly_return_pct
FROM yearly_stats
ORDER BY year_start;

SELECT
    trade_date,
    close_price,
    ROUND(AVG(close_price) OVER (
        ORDER BY trade_date
        ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_50
FROM sp500_index_prices
ORDER BY trade_date;

SELECT
    trade_date,
    close_price,
    ROUND(AVG(close_price) OVER (
        ORDER BY trade_date
        ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_50
FROM sp500_index_prices
ORDER BY trade_date;
