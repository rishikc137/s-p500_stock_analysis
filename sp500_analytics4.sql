WITH ma AS (
    SELECT
        trade_date,
        close_price,
        ROUND(AVG(close_price) OVER (
            ORDER BY trade_date
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
        ), 2) AS ma_50,
        ROUND(AVG(close_price) OVER (
            ORDER BY trade_date
            ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
        ), 2) AS ma_200
    FROM sp500_index_prices
)
SELECT
    trade_date,
    close_price,
    ma_50,
    ma_200,
    CASE
        WHEN ma_50 > ma_200 THEN 'Golden Cross (Bullish)'
        WHEN ma_50 < ma_200 THEN 'Death Cross (Bearish)'
        ELSE 'Neutral'
    END AS signal
FROM ma
ORDER BY trade_date;

WITH ma AS (
    SELECT
        trade_date,
        ROUND(AVG(close_price) OVER (
            ORDER BY trade_date
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
        ), 2) AS ma_50,
        ROUND(AVG(close_price) OVER (
            ORDER BY trade_date
            ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
        ), 2) AS ma_200
    FROM sp500_index_prices
),
signals AS (
    SELECT
        trade_date,
        CASE
            WHEN ma_50 > ma_200 THEN 'Golden Cross (Bullish)'
            WHEN ma_50 < ma_200 THEN 'Death Cross (Bearish)'
            ELSE 'Neutral'
        END AS signal
    FROM ma
)
SELECT
    signal,
    COUNT(*) AS occurrences
FROM signals
GROUP BY signal
ORDER BY occurrences DESC;

WITH ma AS (
    SELECT
        trade_date,
        close_price,
        AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS ma50,
        AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) AS ma200
    FROM sp500_index_prices
)
SELECT
    CASE 
        WHEN ma50 > ma200 THEN 'Bullish'
        ELSE 'Bearish'
    END AS signal,
    COUNT(*) AS days_count
FROM ma
WHERE ma200 IS NOT NULL  -- ensure 200-day average exists
GROUP BY signal;

WITH ma AS (
    SELECT
        trade_date,
        close_price,
        LAG(close_price) OVER (ORDER BY trade_date) AS prev_close,
        AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS ma50,
        AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) AS ma200
    FROM sp500_index_prices
),
classified AS (
    SELECT
        trade_date,
        close_price,
        ((close_price - prev_close) / prev_close) * 100 AS daily_return,
        CASE 
            WHEN ma50 > ma200 THEN 'Bullish'
            ELSE 'Bearish'
        END AS signal
    FROM ma
    WHERE prev_close IS NOT NULL
      AND ma200 IS NOT NULL
)
SELECT
    signal,
    ROUND(AVG(daily_return)::numeric, 3) AS avg_daily_return,
    ROUND(STDDEV(daily_return)::numeric, 3) AS volatility
FROM classified
GROUP BY signal;

WITH sector_returns AS (
    SELECT
        c.sector,
        ROUND(AVG(c.price_earnings)::numeric, 2) AS avg_pe,
        ROUND(AVG(c.dividend_yield)::numeric, 2) AS avg_yield,
        ROUND(SUM(c.market_cap)::numeric, 2) AS total_sector_cap
    FROM companies_financials c
    GROUP BY c.sector
),
market_trend AS (
    SELECT DISTINCT
        CASE 
            WHEN AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW)
               > AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW)
            THEN 'Bullish'
            ELSE 'Bearish'
        END AS market_signal
    FROM sp500_index_prices
)
SELECT
    s.sector,
    s.avg_pe,
    s.avg_yield,
    s.total_sector_cap,
    m.market_signal
FROM sector_returns s
CROSS JOIN (SELECT DISTINCT market_signal FROM market_trend) m
ORDER BY s.total_sector_cap DESC;

WITH sector_returns AS (
    SELECT
        c.sector,
        ROUND(AVG(c.price_earnings)::numeric, 2) AS avg_pe,
        ROUND(AVG(c.dividend_yield)::numeric, 2) AS avg_yield,
        ROUND(SUM(c.market_cap)::numeric, 2) AS total_sector_cap
    FROM companies_financials c
    GROUP BY c.sector
),
market_trend AS (
    SELECT
        CASE 
            WHEN AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW)
               > AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW)
            THEN 'Bullish'
            ELSE 'Bearish'
        END AS market_signal
    FROM sp500_index_prices
    ORDER BY trade_date DESC
    LIMIT 1   -- ✅ only keep the latest signal
)
SELECT
    s.sector,
    s.avg_pe,
    s.avg_yield,
    s.total_sector_cap,
    m.market_signal,
    RANK() OVER (
        ORDER BY 
            CASE 
                WHEN m.market_signal = 'Bullish' THEN s.total_sector_cap
                ELSE s.avg_yield
            END DESC
    ) AS sector_rank
FROM sector_returns s
CROSS JOIN market_trend m;

WITH sector_returns AS (
    SELECT
        c.sector,
        ROUND(AVG(c.price_earnings)::numeric, 2) AS avg_pe,
        ROUND(AVG(c.dividend_yield)::numeric, 2) AS avg_yield,
        ROUND(SUM(c.market_cap)::numeric, 2) AS total_sector_cap
    FROM companies_financials c
    GROUP BY c.sector
),
market_trend AS (
    SELECT
        CASE 
            WHEN AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW)
               > AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW)
            THEN 'Bullish'
            ELSE 'Bearish'
        END AS market_signal
    FROM sp500_index_prices
    ORDER BY trade_date DESC
    LIMIT 1
),
ranked_sectors AS (
    SELECT
        s.sector,
        s.avg_pe,
        s.avg_yield,
        s.total_sector_cap,
        m.market_signal,
        RANK() OVER (
            ORDER BY 
                CASE 
                    WHEN m.market_signal = 'Bullish' THEN s.total_sector_cap
                    ELSE s.avg_yield
                END DESC
        ) AS sector_rank
    FROM sector_returns s
    CROSS JOIN market_trend m
)
SELECT
    c.name,
    c.sector,
    c.market_cap,
    c.price_earnings,
    c.dividend_yield
FROM companies_financials c
JOIN ranked_sectors r
  ON c.sector = r.sector
WHERE r.sector_rank = 1   -- ✅ focus only on top-ranked sector
ORDER BY c.market_cap DESC
LIMIT 10;  -- 🔥 Top 10 companies

WITH sector_returns AS (
    SELECT
        c.sector,
        ROUND(AVG(c.price_earnings)::numeric, 2) AS avg_pe,
        ROUND(AVG(c.dividend_yield)::numeric, 2) AS avg_yield,
        ROUND(SUM(c.market_cap)::numeric, 2) AS total_sector_cap
    FROM companies_financials c
    GROUP BY c.sector
),
market_trend AS (
    SELECT
        CASE 
            WHEN AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW)
               > AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW)
            THEN 'Bullish'
            ELSE 'Bearish'
        END AS market_signal
    FROM sp500_index_prices
    ORDER BY trade_date DESC
    LIMIT 1
),
ranked_sectors AS (
    SELECT
        s.sector,
        s.avg_pe,
        s.avg_yield,
        s.total_sector_cap,
        m.market_signal,
        RANK() OVER (
            ORDER BY 
                CASE 
                    WHEN m.market_signal = 'Bullish' THEN s.total_sector_cap
                    ELSE s.avg_yield
                END DESC
        ) AS sector_rank
    FROM sector_returns s
    CROSS JOIN market_trend m
)
SELECT
    c.name,
    c.sector,
    c.market_cap,
    c.price_earnings,
    c.dividend_yield
FROM companies_financials c
JOIN ranked_sectors r
  ON c.sector = r.sector
WHERE r.sector_rank = 1
  AND c.price_earnings < r.avg_pe   -- ✅ undervalued filter
ORDER BY c.market_cap DESC
LIMIT 10;

SELECT
    sector,
    COUNT(*) AS total_companies,
    ROUND(SUM(market_cap)::numeric, 2) AS total_market_cap,
    ROUND(AVG(price_earnings)::numeric, 2) AS avg_pe_ratio,
    ROUND(AVG(dividend_yield)::numeric, 2) AS avg_dividend_yield
FROM companies_financials
GROUP BY sector
ORDER BY total_market_cap DESC;

-- Monthly % returns for S&P500
WITH monthly_returns AS (
    SELECT
        DATE_TRUNC('month', trade_date) AS month_start,
        FIRST_VALUE(close_price) OVER (PARTITION BY DATE_TRUNC('month', trade_date) ORDER BY trade_date ASC) AS first_close,
        LAST_VALUE(close_price) OVER (PARTITION BY DATE_TRUNC('month', trade_date) ORDER BY trade_date ASC
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_close
    FROM sp500_index_prices
)
SELECT
    month_start,
    ROUND(((last_close - first_close) / first_close) * 100, 2) AS monthly_return
FROM monthly_returns
GROUP BY month_start, first_close, last_close
ORDER BY month_start;

-- Compare sector average P/E to market average P/E
WITH sector_pe AS (
    SELECT
        sector,
        ROUND(AVG(price_earnings)::numeric, 2) AS avg_pe
    FROM companies_financials
    GROUP BY sector
),
market_avg AS (
    SELECT ROUND(AVG(price_earnings)::numeric, 2) AS market_pe
    FROM companies_financials
)
SELECT
    s.sector,
    s.avg_pe,
    m.market_pe,
    CASE
        WHEN s.avg_pe < m.market_pe THEN 'Undervalued'
        WHEN s.avg_pe > m.market_pe THEN 'Overvalued'
        ELSE 'Fairly Valued'
    END AS relative_valuation
FROM sector_pe s
CROSS JOIN market_avg m
ORDER BY s.avg_pe;

SELECT
    sector,
    name AS top_company,
    market_cap
FROM (
    SELECT
        sector,
        name,
        market_cap,
        RANK() OVER (PARTITION BY sector ORDER BY market_cap DESC) AS rank_in_sector
    FROM companies_financials
) ranked
WHERE rank_in_sector = 1
ORDER BY market_cap DESC;

-- Moving average based signal
WITH moving_avg AS (
    SELECT
        trade_date,
        close_price,
        ROUND(AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW), 2) AS ma50,
        ROUND(AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW), 2) AS ma200
    FROM sp500_index_prices
)
SELECT
    trade_date,
    close_price,
    ma50,
    ma200,
    CASE
        WHEN ma50 > ma200 THEN 'Bullish'
        WHEN ma50 < ma200 THEN 'Bearish'
        ELSE 'Neutral'
    END AS market_signal
FROM moving_avg
WHERE ma50 IS NOT NULL AND ma200 IS NOT NULL
ORDER BY trade_date DESC
LIMIT 10;

