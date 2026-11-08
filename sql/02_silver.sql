-- 02 · SILVER: typed, de-duplicated, classified invoice lines
-- Rules
--   * exact duplicate lines are removed (5,268 in the source)
--   * invoices starting with 'C' are cancellations / returns
--   * fee and service codes (postage, bank charges, Amazon fees, manual adjustments) are not products
--   * lines without a CustomerID cannot be attributed to a customer, so they are kept out of customer analysis
CREATE OR REPLACE TABLE silver_lines AS
WITH dedup AS (
    SELECT DISTINCT * FROM bronze_transactions
)
SELECT
    InvoiceNo                                  AS invoice_no,
    StockCode                                  AS stock_code,
    TRIM(Description)                          AS description,
    CAST(Quantity AS INTEGER)                  AS quantity,
    UnitPrice                                  AS unit_price,
    ROUND(Quantity * UnitPrice, 2)             AS line_amount,
    InvoiceDate                                AS invoice_ts,
    CAST(InvoiceDate AS DATE)                  AS invoice_date,
    CustomerID                                 AS customer_id,
    Country                                    AS country,
    InvoiceNo LIKE 'C%'                        AS is_cancellation,
    StockCode IN ('POST', 'DOT', 'M', 'C2', 'D', 'S', 'BANK CHARGES', 'AMAZONFEE',
                  'CRUK', 'PADS', 'B')         AS is_non_product
FROM dedup;

-- Reversed purchases: a purchase line later cancelled in full (same customer, product and quantity).
-- Both sides are removed, otherwise one-off mistakes (e.g. a GBP 168k order cancelled the same day)
-- would inflate both sales and returns.
CREATE OR REPLACE TABLE silver_reversals AS
SELECT DISTINCT p.invoice_no AS purchase_invoice, p.stock_code, p.quantity, p.customer_id,
       c.invoice_no AS cancel_invoice
FROM silver_lines p
JOIN silver_lines c
  ON  c.is_cancellation AND NOT p.is_cancellation
  AND c.customer_id = p.customer_id
  AND c.stock_code  = p.stock_code
  AND c.quantity    = -p.quantity
  AND c.invoice_ts >= p.invoice_ts
WHERE p.customer_id IS NOT NULL AND p.quantity > 0;

-- Valid product sales attributable to a known customer
CREATE OR REPLACE TABLE silver_sales AS
SELECT l.*
FROM silver_lines l
WHERE l.customer_id IS NOT NULL
  AND NOT l.is_cancellation
  AND NOT l.is_non_product
  AND l.quantity > 0
  AND l.unit_price > 0
  AND NOT EXISTS (SELECT 1 FROM silver_reversals r
                  WHERE r.purchase_invoice = l.invoice_no AND r.stock_code = l.stock_code
                    AND r.quantity = l.quantity);

-- Genuine returns (cancellations that are not full reversals), stored as positive amounts
CREATE OR REPLACE TABLE silver_returns AS
SELECT l.customer_id, l.invoice_date, -l.line_amount AS return_amount
FROM silver_lines l
WHERE l.customer_id IS NOT NULL
  AND l.is_cancellation
  AND NOT l.is_non_product
  AND NOT EXISTS (SELECT 1 FROM silver_reversals r
                  WHERE r.cancel_invoice = l.invoice_no AND r.stock_code = l.stock_code
                    AND r.quantity = -l.quantity);
