"""Run the whole pipeline: raw CSV -> bronze -> silver -> gold, then export the gold tables.
Usage:  pip install -r requirements.txt   then   python run.py
"""
import duckdb, json, pathlib
ROOT = pathlib.Path(__file__).parent
(ROOT / "output").mkdir(exist_ok=True)
con = duckdb.connect(str(ROOT / "output" / "retail.duckdb"))
for sql in sorted((ROOT / "sql").glob("*.sql")):
    con.execute(sql.read_text())
    print("ran", sql.name)
tables = ["gold_segment_summary", "gold_rf_grid", "gold_monthly", "gold_migration",
          "gold_segment_trend", "gold_cohorts"]
out = {}
for t in tables:
    con.execute(f"COPY {t} TO '{ROOT / 'output' / (t + '.csv')}' (HEADER)")
    df = con.sql(f"SELECT * FROM {t}").df()
    for c in df.columns:
        if str(df[c].dtype).startswith("datetime") or "date" in str(df[c].dtype):
            df[c] = df[c].astype(str).str[:10]
    out[t] = df.to_dict(orient="records")
out["kpis"] = con.sql("""
    SELECT (SELECT COUNT(*) FROM bronze_transactions) AS raw_rows,
           (SELECT COUNT(*) FROM silver_sales) AS clean_lines,
           (SELECT COUNT(*) FROM gold_rfm) AS customers,
           (SELECT COUNT(DISTINCT invoice_no) FROM silver_sales) AS orders,
           (SELECT ROUND(SUM(sales)) FROM gold_rfm) AS sales,
           (SELECT ROUND(SUM(returns)) FROM gold_rfm) AS returns,
           (SELECT MIN(invoice_date)::VARCHAR FROM silver_sales) AS first_date,
           (SELECT MAX(invoice_date)::VARCHAR FROM silver_sales) AS last_date,
           (SELECT ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 1) FROM gold_rfm) AS repeat_rate_pct
""").df().to_dict(orient="records")[0]
(ROOT / "output" / "report_data.json").write_text(json.dumps(out, default=str))
# the HTML report reads the same numbers
(ROOT / "report" / "data.js").write_text("const DATA = " + json.dumps(out, default=str, separators=(",", ":")) + ";\n")
print("exported", len(tables), "tables and report/data.js")
