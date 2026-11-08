-- 05 · GOLD: segment migration between quarterly snapshots
-- Each snapshot scores customers using only the orders placed before that date, with the same thresholds.
CREATE OR REPLACE TABLE gold_snapshots AS
WITH snaps(snapshot_date, label) AS (
    VALUES (DATE '2011-04-01', 'Q1 2011'), (DATE '2011-07-01', 'Q2 2011'),
           (DATE '2011-10-01', 'Q3 2011'), (DATE '2011-12-10', 'Q4 2011')
),
hist AS (
    SELECT s.snapshot_date, s.label, x.customer_id,
           COUNT(DISTINCT x.invoice_no) AS orders,
           SUM(x.line_amount) AS sales,
           DATE_DIFF('day', MAX(x.invoice_date), s.snapshot_date) AS recency_days
    FROM snaps s
    JOIN silver_sales x ON x.invoice_date < s.snapshot_date
    GROUP BY s.snapshot_date, s.label, x.customer_id
)
SELECT *, rfm_segment(r_score(recency_days), f_score(orders)) AS segment
FROM hist;

-- Where did each Q3 segment end up by the final snapshot? (customers who first bought after Q3 = 'New since Q3')
CREATE OR REPLACE TABLE gold_migration AS
SELECT
    COALESCE(a.segment, 'New since Q3')  AS from_segment,
    b.segment                            AS to_segment,
    COUNT(*)                             AS customers,
    ROUND(SUM(b.sales))                  AS sales_to_date
FROM (SELECT * FROM gold_snapshots WHERE label = 'Q4 2011') b
LEFT JOIN (SELECT * FROM gold_snapshots WHERE label = 'Q3 2011') a USING (customer_id)
GROUP BY ALL
ORDER BY from_segment, to_segment;

-- Segment sizes at each snapshot
CREATE OR REPLACE TABLE gold_segment_trend AS
SELECT label, snapshot_date, segment, COUNT(*) AS customers, ROUND(SUM(sales)) AS sales
FROM gold_snapshots
GROUP BY ALL ORDER BY snapshot_date, segment;
