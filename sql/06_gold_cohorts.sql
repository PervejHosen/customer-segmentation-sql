-- 06 · GOLD: monthly acquisition cohorts and retention
-- Cohort = month of first order. Retention = share of the cohort that ordered again in month N after.
-- December 2011 only has 9 days of data, so the last column is partial.
CREATE OR REPLACE TABLE gold_cohorts AS
WITH first_month AS (
    SELECT customer_id, DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM silver_sales GROUP BY 1
),
activity AS (
    SELECT DISTINCT customer_id, DATE_TRUNC('month', invoice_date) AS active_month FROM silver_sales
),
joined AS (
    SELECT f.cohort_month,
           DATE_DIFF('month', f.cohort_month, a.active_month) AS month_number,
           a.customer_id
    FROM first_month f JOIN activity a USING (customer_id)
)
SELECT cohort_month, month_number,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(100.0 * COUNT(DISTINCT customer_id)
             / FIRST_VALUE(COUNT(DISTINCT customer_id)) OVER (PARTITION BY cohort_month ORDER BY month_number), 1) AS retention_pct
FROM joined
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;
