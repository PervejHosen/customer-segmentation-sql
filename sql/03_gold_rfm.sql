-- 03 · GOLD: RFM scores and segments
-- Snapshot date = the day after the last invoice (2011-12-10), so recency is "days since last order".
-- Scores use fixed business thresholds (not quantiles) so they mean the same thing at every snapshot
-- and ties (e.g. the 1,505 one-time buyers) never get split across different scores.
--   Recency days : <=14 -> 5 | 15-30 -> 4 | 31-90 -> 3 | 91-180 -> 2 | >180 -> 1
--   Orders       : 6+ -> 5   | 4-5 -> 4   | 3 -> 3     | 2 -> 2      | 1 -> 1
--   Sales (GBP)  : 2000+ -> 5 | 1000-1999 -> 4 | 500-999 -> 3 | 250-499 -> 2 | <250 -> 1
-- Segments follow the standard R x F grid, which covers all 25 combinations (nobody falls into "other").

CREATE OR REPLACE MACRO r_score(days) AS
    CASE WHEN days <= 14 THEN 5 WHEN days <= 30 THEN 4 WHEN days <= 90 THEN 3 WHEN days <= 180 THEN 2 ELSE 1 END;
CREATE OR REPLACE MACRO f_score(orders) AS
    CASE WHEN orders >= 6 THEN 5 WHEN orders >= 4 THEN 4 WHEN orders = 3 THEN 3 WHEN orders = 2 THEN 2 ELSE 1 END;
CREATE OR REPLACE MACRO m_score(sales) AS
    CASE WHEN sales >= 2000 THEN 5 WHEN sales >= 1000 THEN 4 WHEN sales >= 500 THEN 3 WHEN sales >= 250 THEN 2 ELSE 1 END;
CREATE OR REPLACE MACRO rfm_segment(r, f) AS
    CASE
        WHEN r <= 2 AND f <= 2 THEN 'Hibernating'
        WHEN r <= 2 AND f <= 4 THEN 'At Risk'
        WHEN r <= 2 AND f = 5  THEN 'Can''t Lose'
        WHEN r = 3  AND f <= 2 THEN 'About to Sleep'
        WHEN r = 3  AND f = 3  THEN 'Need Attention'
        WHEN r <= 4 AND f >= 4 THEN 'Loyal'
        WHEN r = 4  AND f = 1  THEN 'Promising'
        WHEN r = 5  AND f = 1  THEN 'New'
        WHEN r >= 4 AND f <= 3 THEN 'Potential Loyalist'
        ELSE 'Champions'          -- r = 5 and f >= 4
    END;

-- One row per customer: behaviour up to the snapshot
CREATE OR REPLACE TABLE gold_customers AS
WITH s AS (SELECT DATE '2011-12-10' AS snapshot_date)
SELECT
    c.customer_id,
    ANY_VALUE(c.country)                                        AS country,
    MIN(c.invoice_date)                                         AS first_order_date,
    MAX(c.invoice_date)                                         AS last_order_date,
    COUNT(DISTINCT c.invoice_no)                                AS orders,
    ROUND(SUM(c.line_amount), 2)                                AS sales,
    ROUND(SUM(c.line_amount) / COUNT(DISTINCT c.invoice_no), 2) AS avg_order_value,
    DATE_DIFF('day', MAX(c.invoice_date), ANY_VALUE(s.snapshot_date)) AS recency_days
FROM silver_sales c CROSS JOIN s
GROUP BY c.customer_id;

CREATE OR REPLACE TABLE gold_rfm AS
SELECT
    g.*,
    COALESCE(r.returns, 0)                       AS returns,
    r_score(recency_days)                        AS r,
    f_score(orders)                              AS f,
    m_score(sales)                               AS m,
    r_score(recency_days)::VARCHAR || f_score(orders)::VARCHAR || m_score(sales)::VARCHAR AS rfm_code,
    rfm_segment(r_score(recency_days), f_score(orders)) AS segment
FROM gold_customers g
LEFT JOIN (SELECT customer_id, ROUND(SUM(return_amount), 2) AS returns FROM silver_returns GROUP BY 1) r
       USING (customer_id);
