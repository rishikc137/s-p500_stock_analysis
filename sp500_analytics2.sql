SELECT
    sector,
    COUNT(*) AS total_companies,
    ROUND(AVG(price_earnings)::numeric, 2) AS avg_pe_ratio,
    ROUND(AVG(dividend_yield)::numeric, 2) AS avg_dividend_yield,
    ROUND(SUM(market_cap)::numeric, 2) AS total_market_cap
FROM companies_financials
GROUP BY sector
ORDER BY total_market_cap DESC;

SELECT *
FROM (
    SELECT
        sector,
        name,
        market_cap,
        RANK() OVER (PARTITION BY sector ORDER BY market_cap DESC) AS rank_within_sector
    FROM companies_financials
) ranked
WHERE rank_within_sector <= 3
ORDER BY sector, rank_within_sector;

SELECT
    name,
    sector,
    market_cap,
    price_earnings,
    CASE
        WHEN price_earnings < 15 THEN 'Undervalued'
        WHEN price_earnings BETWEEN 15 AND 25 THEN 'Fairly Valued'
        WHEN price_earnings > 25 THEN 'Overvalued'
        ELSE 'No Data'
    END AS valuation_category
FROM companies_financials
WHERE price_earnings IS NOT NULL
ORDER BY sector, valuation_category;

SELECT
    name,
    sector,
    market_cap,
    dividend_yield,
    price_earnings
FROM
    companies_financials
WHERE
    sector = 'Information Technology'
    AND dividend_yield > 2
ORDER BY
    market_cap DESC;

SELECT
    name,
    sector,
    market_cap,
    price_earnings
FROM
    companies_financials
WHERE
    sector = 'Financials'
    AND price_earnings BETWEEN 10 AND 20
    AND market_cap > 50000000000
ORDER BY
    price_earnings ASC;

SELECT
    sector,
    name,
    market_cap,
    RANK() OVER (PARTITION BY sector ORDER BY market_cap DESC) AS rank_in_sector
FROM
    companies_financials
ORDER BY
    sector,
    rank_in_sector;

SELECT * 
FROM sp500_index_prices 
LIMIT 5;

WITH monthly_prices AS (
    SELECT
        DATE_TRUNC('month', "Date") AS month_start,
        FIRST_VALUE(close) OVER (
            PARTITION BY DATE_TRUNC('month', "Date")
            ORDER BY "Date" ASC
        ) AS first_close,
        LAST_VALUE(close) OVER (
            PARTITION BY DATE_TRUNC('month', "Date")
            ORDER BY "Date" ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_close
    FROM sp500_index_prices
)
SELECT
    month_start,
    ROUND(((last_close - first_close) / first_close) * 100, 2) AS monthly_return_pct
FROM monthly_prices
GROUP BY month_start, first_close, last_close
ORDER BY month_start;




