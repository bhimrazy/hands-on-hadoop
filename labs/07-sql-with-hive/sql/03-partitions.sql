SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

DROP TABLE IF EXISTS sales_by_country;
CREATE TABLE sales_by_country (
  order_id INT,
  customer_id INT,
  product STRING,
  quantity INT,
  unit_price DOUBLE,
  order_date STRING
)
PARTITIONED BY (country STRING)
STORED AS ORC;

INSERT OVERWRITE TABLE sales_by_country PARTITION (country)
SELECT order_id, customer_id, product, quantity, unit_price, order_date, country
FROM sales_raw;

SHOW PARTITIONS sales_by_country;
SELECT COUNT(*) AS orders_in_nepal FROM sales_by_country WHERE country = 'Nepal';
