SELECT 
    sector,
    SUM(market_cap)/1e12 AS total_market_cap_trillion,
    ROUND(AVG(price_earnings)::numeric, 2) AS avg_pe
FROM companies_financials
GROUP BY sector
ORDER BY total_market_cap_trillion DESC;

SELECT 
    sector,
    ROUND(SUM(market_cap)/1e12, 2) AS total_market_cap_trillion,
    COUNT(*) AS total_companies
FROM companies_financials
GROUP BY sector
ORDER BY total_market_cap_trillion DESC;

SELECT
    DATE_TRUNC('month', trade_date) AS month_start,
    ROUND(AVG(close_price), 2) AS avg_close_price
FROM sp500_index_prices
GROUP BY DATE_TRUNC('month', trade_date)
ORDER BY month_start;

SELECT
    name,
    sector,
    ROUND(market_cap/1e9, 2) AS market_cap_billion,
    ROUND(price_earnings, 2) AS pe_ratio
FROM companies_financials
ORDER BY market_cap DESC
LIMIT 10;

SELECT
    CASE
        WHEN price_earnings < 10 THEN 'Low P/E (<10)'
        WHEN price_earnings BETWEEN 10 AND 20 THEN 'Mid P/E (10-20)'
        WHEN price_earnings BETWEEN 20 AND 40 THEN 'High P/E (20-40)'
        ELSE 'Very High P/E (>40)'
    END AS pe_bucket,
    COUNT(*) AS companies_count
FROM companies_financials
GROUP BY pe_bucket
ORDER BY companies_count DESC;

SELECT
    DATE_TRUNC('month', trade_date) AS month_start,
    ROUND(MAX(close_price) - MIN(close_price), 2) AS monthly_volatility
FROM sp500_index_prices
GROUP BY DATE_TRUNC('month', trade_date)
ORDER BY month_start;

WITH moving_averages AS (
    SELECT
        trade_date,
        AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS ma50,
        AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) AS ma200
    FROM sp500_index_prices
)
SELECT
    trade_date,
    CASE
        WHEN ma50 > ma200 THEN 'Bullish'
        ELSE 'Bearish'
    END AS market_signal
FROM moving_averages
ORDER BY trade_date DESC
LIMIT 20;
