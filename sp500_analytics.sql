SELECT COUNT(*) FROM companies_financials;

SELECT * 
FROM companies_financials
LIMIT 10;

SELECT sector, COUNT(*) AS company_count
FROM companies_financials
GROUP BY sector
ORDER BY company_count DESC;

SELECT name, sector, market_cap
FROM companies_financials
ORDER BY market_cap DESC
LIMIT 10;

SELECT name, sector, dividend_yield
FROM companies_financials
WHERE dividend_yield IS NOT NULL
ORDER BY dividend_yield DESC
LIMIT 10;

SELECT sector, ROUND(AVG(price_earnings), 2) AS avg_pe
FROM companies_financials
WHERE price_earnings IS NOT NULL
GROUP BY sector
ORDER BY avg_pe DESC;

SELECT 
    ROUND(SUM(market_cap) / 
          (SELECT SUM(market_cap) FROM companies_financials) * 100, 2) AS tech_share_percent
FROM companies_financials
WHERE sector = 'Information Technology';

SELECT 
    name,
    sector,
    market_cap,
    pe_ratio,
    dividend_yield
FROM 
    companies_financials
WHERE 
    pe_ratio < 20
    AND dividend_yield > 3
ORDER BY 
    dividend_yield DESC;

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'companies_financials';

SELECT 
    name,
    sector,
    market_cap,
    price_earnings,
    dividend_yield
FROM 
    companies_financials
WHERE 
    price_earnings < 20
    AND dividend_yield > 3
ORDER BY 
    dividend_yield DESC;

SELECT
    sector,
    ROUND(AVG(price_earnings)::numeric, 2) AS avg_pe_ratio,
    ROUND(AVG(dividend_yield)::numeric, 2) AS avg_dividend_yield,
    ROUND(SUM(market_cap)::numeric, 0) AS total_market_cap
FROM
    companies_financials
GROUP BY
    sector
ORDER BY
    total_market_cap DESC;

SELECT *
FROM (
    SELECT
        name,
        sector,
        market_cap,
        RANK() OVER (PARTITION BY sector ORDER BY market_cap DESC) AS rank_in_sector
    FROM
        companies_financials
) ranked
WHERE rank_in_sector <= 3
ORDER BY sector, rank_in_sector;
