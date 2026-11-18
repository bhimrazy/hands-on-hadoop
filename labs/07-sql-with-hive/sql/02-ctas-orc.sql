DROP TABLE IF EXISTS sales_orc;
CREATE TABLE sales_orc STORED AS ORC AS
SELECT order_id, customer_id, product, country, quantity, unit_price,
       quantity * unit_price AS revenue, order_date
FROM sales_raw;

SELECT COUNT(*) AS rows_in_orc FROM sales_orc;
DESCRIBE sales_orc;
