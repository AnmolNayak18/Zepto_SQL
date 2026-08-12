-- Zepto Inventory & Pricing Analysis
-- PostgreSQL

-- ============================
-- SETUP
-- ============================

DROP TABLE IF EXISTS zepto CASCADE;

CREATE TABLE zepto (
    sku_id                  SERIAL PRIMARY KEY,
    category                VARCHAR(120)   NOT NULL,
    name                    VARCHAR(150)   NOT NULL,
    mrp                     NUMERIC(10,2)  CHECK (mrp >= 0),
    discountPercent         NUMERIC(5,2)   CHECK (discountPercent BETWEEN 0 AND 100),
    availableQuantity       INTEGER        CHECK (availableQuantity >= 0),
    discountedSellingPrice  NUMERIC(10,2)  CHECK (discountedSellingPrice >= 0),
    weightInGms             INTEGER        CHECK (weightInGms >= 0),
    outOfStock              BOOLEAN        NOT NULL DEFAULT FALSE,
    quantity                INTEGER
);

CREATE INDEX idx_zepto_category   ON zepto (category);
CREATE INDEX idx_zepto_outofstock ON zepto (outOfStock);

-- \copy zepto(category, name, mrp, discountPercent, availableQuantity,
--             discountedSellingPrice, weightInGms, outOfStock, quantity)
-- FROM 'zepto_v2.csv' WITH (FORMAT csv, HEADER true);


-- ============================
-- EXPLORATION
-- ============================

SELECT COUNT(*) AS total_rows FROM zepto;

SELECT * FROM zepto LIMIT 10;

SELECT *
FROM zepto
WHERE name IS NULL OR category IS NULL OR mrp IS NULL
   OR discountPercent IS NULL OR discountedSellingPrice IS NULL
   OR weightInGms IS NULL OR availableQuantity IS NULL
   OR outOfStock IS NULL OR quantity IS NULL;

SELECT
    category, name, mrp, discountPercent, availableQuantity,
    discountedSellingPrice, weightInGms, outOfStock, quantity,
    COUNT(*) AS duplicate_count
FROM zepto
GROUP BY
    category, name, mrp, discountPercent, availableQuantity,
    discountedSellingPrice, weightInGms, outOfStock, quantity
HAVING COUNT(*) > 1;

SELECT COUNT(DISTINCT category) AS distinct_categories FROM zepto;

SELECT DISTINCT category FROM zepto ORDER BY category;

SELECT outOfStock, COUNT(*) AS product_count
FROM zepto
GROUP BY outOfStock
ORDER BY outOfStock;

SELECT name, COUNT(sku_id) AS number_of_skus
FROM zepto
GROUP BY name
HAVING COUNT(sku_id) > 1
ORDER BY number_of_skus DESC;


-- ============================
-- CLEANING
-- ============================

SELECT * FROM zepto WHERE mrp = 0 OR discountedSellingPrice = 0;

DELETE FROM zepto WHERE mrp = 0;

-- prices come in as paise, convert to rupees
UPDATE zepto
SET mrp = mrp / 100.0,
    discountedSellingPrice = discountedSellingPrice / 100.0;

SELECT * FROM zepto WHERE discountedSellingPrice > mrp;

SELECT name, mrp, discountedSellingPrice FROM zepto LIMIT 20;


-- ============================
-- PRICING
-- ============================

SELECT DISTINCT name, mrp, discountPercent
FROM zepto
ORDER BY discountPercent DESC
LIMIT 10;

SELECT DISTINCT name, mrp
FROM zepto
WHERE outOfStock = TRUE AND mrp > 300
ORDER BY mrp DESC;

SELECT DISTINCT name, mrp, discountPercent
FROM zepto
WHERE mrp > 500 AND discountPercent < 10
ORDER BY mrp DESC, discountPercent DESC;

SELECT category, ROUND(AVG(discountPercent), 2) AS average_discount
FROM zepto
GROUP BY category
ORDER BY average_discount DESC
LIMIT 5;

SELECT DISTINCT
    name, weightInGms, discountedSellingPrice,
    ROUND(discountedSellingPrice / NULLIF(weightInGms, 0), 4) AS price_per_gram
FROM zepto
WHERE weightInGms >= 100
ORDER BY price_per_gram;


-- ============================
-- INVENTORY
-- ============================

-- inventory value, not revenue - no sales data here
SELECT category, ROUND(SUM(discountedSellingPrice * availableQuantity), 2) AS inventory_value
FROM zepto
GROUP BY category
ORDER BY inventory_value DESC;

SELECT category, SUM(weightInGms * availableQuantity) AS total_inventory_weight_gms
FROM zepto
GROUP BY category
ORDER BY total_inventory_weight_gms DESC;

SELECT
    category,
    COUNT(*) AS total_products,
    SUM(CASE WHEN outOfStock = TRUE THEN 1 ELSE 0 END) AS out_of_stock_products,
    ROUND(100.0 * SUM(CASE WHEN outOfStock = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS out_of_stock_rate
FROM zepto
GROUP BY category
ORDER BY out_of_stock_rate DESC;

SELECT category, SUM(availableQuantity) AS total_available_quantity
FROM zepto
GROUP BY category
ORDER BY total_available_quantity DESC;

SELECT
    category,
    ROUND(AVG(discountPercent), 2) AS average_discount,
    ROUND(100.0 * SUM(CASE WHEN outOfStock = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS out_of_stock_rate
FROM zepto
GROUP BY category
ORDER BY average_discount DESC;


-- ============================
-- SEGMENTATION
-- ============================

SELECT DISTINCT
    name, weightInGms,
    CASE
        WHEN weightInGms < 1000 THEN 'Low'
        WHEN weightInGms < 5000 THEN 'Medium'
        ELSE 'Bulk'
    END AS weight_category
FROM zepto;

SELECT DISTINCT
    name, discountPercent,
    CASE
        WHEN discountPercent < 10 THEN 'Low Discount'
        WHEN discountPercent < 30 THEN 'Medium Discount'
        WHEN discountPercent < 50 THEN 'High Discount'
        ELSE 'Very High Discount'
    END AS discount_category
FROM zepto;

SELECT DISTINCT name, mrp, NTILE(4) OVER (ORDER BY mrp) AS price_quartile
FROM zepto;


-- ============================
-- WINDOW FUNCTIONS
-- ============================

SELECT
    category, name, discountedSellingPrice,
    RANK() OVER (PARTITION BY category ORDER BY discountedSellingPrice DESC) AS price_rank
FROM zepto;

WITH ranked_products AS (
    SELECT
        category, name, discountedSellingPrice,
        RANK() OVER (PARTITION BY category ORDER BY discountedSellingPrice DESC) AS price_rank
    FROM zepto
)
SELECT category, name, discountedSellingPrice, price_rank
FROM ranked_products
WHERE price_rank <= 3
ORDER BY category, price_rank;

SELECT
    category, name, discountedSellingPrice,
    ROUND(
        SUM(discountedSellingPrice * availableQuantity) OVER (
            PARTITION BY category
            ORDER BY discountedSellingPrice DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS running_inventory_value
FROM zepto
ORDER BY category, discountedSellingPrice DESC;


-- ============================
-- CTE ANALYSIS
-- ============================

WITH category_inventory AS (
    SELECT category, SUM(discountedSellingPrice * availableQuantity) AS inventory_value
    FROM zepto
    GROUP BY category
)
SELECT
    category,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(100.0 * inventory_value / SUM(inventory_value) OVER (), 2) AS inventory_value_percentage
FROM category_inventory
ORDER BY inventory_value DESC;

WITH discount_segments AS (
    SELECT
        category, discountPercent,
        CASE
            WHEN discountPercent < 10 THEN 'Low Discount'
            WHEN discountPercent < 30 THEN 'Medium Discount'
            WHEN discountPercent < 50 THEN 'High Discount'
            ELSE 'Very High Discount'
        END AS discount_category
    FROM zepto
)
SELECT discount_category, COUNT(*) AS product_count, ROUND(AVG(discountPercent), 2) AS average_discount
FROM discount_segments
GROUP BY discount_category
ORDER BY average_discount DESC;

-- categories that are both high value and high risk
WITH category_metrics AS (
    SELECT
        category,
        SUM(discountedSellingPrice * availableQuantity) AS inventory_value,
        ROUND(100.0 * SUM(CASE WHEN outOfStock = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS out_of_stock_rate
    FROM zepto
    GROUP BY category
)
SELECT *
FROM category_metrics
WHERE inventory_value >= (SELECT AVG(inventory_value) FROM category_metrics)
  AND out_of_stock_rate  >= (SELECT AVG(out_of_stock_rate) FROM category_metrics)
ORDER BY out_of_stock_rate DESC;


-- ============================
-- KPI VIEW
-- ============================

CREATE OR REPLACE VIEW vw_category_kpi_summary AS
SELECT
    category,
    COUNT(*) AS total_products,
    ROUND(AVG(mrp), 2) AS average_mrp,
    ROUND(AVG(discountPercent), 2) AS average_discount,
    ROUND(AVG(discountedSellingPrice), 2) AS average_selling_price,
    SUM(availableQuantity) AS total_available_quantity,
    SUM(CASE WHEN outOfStock = TRUE THEN 1 ELSE 0 END) AS out_of_stock_products,
    ROUND(100.0 * SUM(CASE WHEN outOfStock = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS out_of_stock_rate,
    ROUND(SUM(discountedSellingPrice * availableQuantity), 2) AS inventory_value
FROM zepto
GROUP BY category;

SELECT * FROM vw_category_kpi_summary ORDER BY inventory_value DESC;


-- ============================
-- BUSINESS QUESTIONS
-- ============================

-- highest average discount by category
SELECT category, average_discount
FROM vw_category_kpi_summary
ORDER BY average_discount DESC;

-- highest out-of-stock rate by category
SELECT category, out_of_stock_rate
FROM vw_category_kpi_summary
ORDER BY out_of_stock_rate DESC;

-- highest inventory value by category
SELECT category, inventory_value
FROM vw_category_kpi_summary
ORDER BY inventory_value DESC;

-- best value per gram
SELECT DISTINCT
    name, weightInGms, discountedSellingPrice,
    ROUND(discountedSellingPrice / NULLIF(weightInGms, 0), 4) AS price_per_gram
FROM zepto
WHERE weightInGms >= 100
ORDER BY price_per_gram
LIMIT 10;

-- expensive products currently out of stock
SELECT DISTINCT name, category, mrp
FROM zepto
WHERE outOfStock = TRUE AND mrp > 500
ORDER BY mrp DESC;
