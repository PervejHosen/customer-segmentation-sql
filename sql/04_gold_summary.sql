-- 04 · GOLD: segment summary (the main table behind the report)
CREATE OR REPLACE TABLE gold_segment_summary AS
SELECT
    segment,
    COUNT(*)                                                    AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_customers,
    ROUND(SUM(sales))                                           AS sales,
    ROUND(100.0 * SUM(sales) / SUM(SUM(sales)) OVER (), 1)      AS pct_sales,
    ROUND(MEDIAN(recency_days))                                 AS median_recency_days,
    ROUND(AVG(orders), 1)                                       AS avg_orders,
    ROUND(AVG(sales))                                           AS avg_sales,
    ROUND(SUM(sales) / SUM(orders))                             AS avg_order_value,
    ROUND(100.0 * SUM(returns) / NULLIF(SUM(sales), 0), 1)      AS return_rate_pct
FROM gold_rfm
GROUP BY segment
ORDER BY sales DESC;

-- R x F grid: customer counts for the heatmap
CREATE OR REPLACE TABLE gold_rf_grid AS
SELECT r, f, rfm_segment(r, f) AS segment, COUNT(*) AS customers, ROUND(SUM(sales)) AS sales
FROM gold_rfm
GROUP BY ALL
ORDER BY r DESC, f;

-- Monthly trend: sales and active customers
CREATE OR REPLACE TABLE gold_monthly AS
SELECT DATE_TRUNC('month', invoice_date) AS month,
       ROUND(SUM(line_amount)) AS sales,
       COUNT(DISTINCT customer_id) AS active_customers,
       COUNT(DISTINCT invoice_no) AS orders
FROM silver_sales
GROUP BY 1 ORDER BY 1;
