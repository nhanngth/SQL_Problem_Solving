WITH
  sales AS (
  SELECT
    product_id,
    ordered_at,
    SUM(quantity_ordered) AS total_quantity
  FROM sales_table
  GROUP BY
    product_id, ordered_at),
  min_date AS (
  SELECT
    product_id,
    MIN(updated_at) AS min_updated
  FROM prices_table
  GROUP BY product_id),
  t1 AS (
  SELECT
    s.product_id,
    s.ordered_at,
    s.total_quantity,
    p.updated_at,
    m.min_updated,
    ROW_NUMBER() OVER(PARTITION BY s.product_id, s.ordered_at, s.total_quantity ORDER BY p.updated_at DESC) AS rnk
  FROM sales s
  LEFT JOIN prices_table p
  ON s.product_id = p.product_id AND s.ordered_at > p.updated_at
  LEFT JOIN min_date m
  ON s.product_id = m.product_id ),
  t2 AS (
  SELECT
    product_id,
    ordered_at,
    total_quantity,
    CASE WHEN updated_at IS NULL THEN min_updated ELSE updated_at END AS updated
  FROM t1
  WHERE rnk = 1),
  t3 AS (
  SELECT
    t2.product_id,
    t2.ordered_at,
    t2.total_quantity,
    CASE WHEN t2.ordered_at <= t2.updated THEN p.old_price ELSE p.new_price END AS price
  FROM t2
  INNER JOIN prices_table p
  ON t2.product_id = p.product_id AND t2.updated = p.updated_at)
SELECT
  product_id,
  price,
  SUM(total_quantity * price) AS total_revenue
FROM t3
GROUP BY product_id, price
ORDER BY product_id, total_revenue DESC
