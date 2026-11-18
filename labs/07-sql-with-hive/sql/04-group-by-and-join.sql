SELECT country, COUNT(*) AS orders, ROUND(SUM(revenue), 2) AS revenue
FROM sales_orc
GROUP BY country
ORDER BY revenue DESC;

SELECT c.name, c.city, ROUND(SUM(s.revenue), 2) AS spent
FROM sales_orc s
JOIN customers_raw c ON s.customer_id = c.customer_id
GROUP BY c.name, c.city
ORDER BY spent DESC
LIMIT 5;

DROP TABLE IF EXISTS top_products;
CREATE TABLE top_products STORED AS ORC AS
SELECT product, SUM(quantity) AS units, ROUND(SUM(revenue), 2) AS revenue
FROM sales_orc
GROUP BY product
ORDER BY revenue DESC;

SELECT * FROM top_products;
