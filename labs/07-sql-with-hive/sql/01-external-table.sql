DROP TABLE IF EXISTS sales_raw;
CREATE EXTERNAL TABLE sales_raw (
  order_id INT,
  customer_id INT,
  product STRING,
  country STRING,
  quantity INT,
  unit_price DOUBLE,
  order_date STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/lab/07/sales'
TBLPROPERTIES ('skip.header.line.count' = '1');

DROP TABLE IF EXISTS customers_raw;
CREATE EXTERNAL TABLE customers_raw (
  customer_id INT,
  name STRING,
  country STRING,
  city STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/lab/07/customers'
TBLPROPERTIES ('skip.header.line.count' = '1');

SELECT * FROM sales_raw LIMIT 5;
SELECT COUNT(*) AS rows_in_csv FROM sales_raw;
