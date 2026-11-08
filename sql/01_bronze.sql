-- 01 · BRONZE: raw transactions, loaded as-is (one row per invoice line)
CREATE OR REPLACE TABLE bronze_transactions AS
SELECT *
FROM read_csv('data/raw/online_retail.csv.gz', header = true,
     columns = {'InvoiceNo': 'VARCHAR', 'StockCode': 'VARCHAR', 'Description': 'VARCHAR',
                'Quantity': 'DOUBLE', 'InvoiceDate': 'TIMESTAMP', 'UnitPrice': 'DOUBLE',
                'CustomerID': 'BIGINT', 'Country': 'VARCHAR'});
