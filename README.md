# Zepto E-Commerce Analytics (SQL Project)

Exploratory data analysis, cleaning, and business-focused reporting on a
quick-commerce product catalog, built in PostgreSQL.

## Overview

Zepto is a quick-commerce grocery delivery platform. This project takes a raw
product-catalog export — pricing, discounting, stock levels, and package
weight at the SKU level — and turns it into answers to questions an
inventory or category analyst would actually be asked:

- Where is discounting heaviest, and is it working as intended?
- Which categories are most exposed to stock-outs?
- Where is inventory value concentrated?
- Which products are the best (and worst) value per gram?
- Which high-value products are currently unsellable due to stock-outs?

## Dataset

| | |
|---|---|
| **Grain** | One row per SKU (a product can have multiple SKUs — e.g. different pack sizes) |
| **Columns** | `category`, `name`, `mrp`, `discountPercent`, `availableQuantity`, `discountedSellingPrice`, `weightInGms`, `outOfStock`, `quantity` |
| **Source** | [Zepto Inventory Dataset, Kaggle](https://www.kaggle.com/datasets/palvinder2006/zepto-inventory-dataset) (`zepto_v2.csv`) |

**Important caveat:** this is a point-in-time inventory snapshot, not a
transaction log — there's no "units sold" or date field. `discountedSellingPrice
× availableQuantity` is therefore reported throughout as **estimated
inventory value**, never as revenue.

## Tools

- PostgreSQL 14+
- Standard SQL client (`psql`, DBeaver, pgAdmin, etc.)

## Project Structure

```
zepto_data_analytics.sql   -- full script: schema, cleaning, analysis, KPI view
README.md                  -- this file
```

## What's in the script

The script is organized into 10 numbered sections, runnable top to bottom:

1. **Schema Setup** — table with `CHECK` constraints, column comments, and
   indexes on the columns used most in `GROUP BY` / `WHERE`
2. **Data Exploration** — row counts, null checks, duplicate detection,
   category inventory, stock-status breakdown
3. **Data Cleaning** — removing invalid zero-price rows, converting prices
   from paise to rupees, a post-cleaning sanity check
4. **Product & Pricing Analysis** — top discounts, out-of-stock premium
   products, price-per-gram value analysis
5. **Inventory Analysis** — inventory value and weight by category,
   out-of-stock rate by category, discount-vs-stockout signal
6. **Product Segmentation** — `CASE`-based weight and discount tiers, plus
   `NTILE` price quartiles
7. **Window Functions** — `RANK()` for top products per category, and a
   running (cumulative) inventory-value calculation
8. **CTE-Based Business Analysis** — category share of inventory value,
   discount-segment averages, and a combined "high value + high stock-out
   risk" category screen
9. **Reporting View** — `vw_category_kpi_summary`, a reusable view packaging
   the core category KPIs for downstream BI tools
10. **Final Business Questions** — five direct Q&A queries answering the
    project's original objective

## Key Skills Demonstrated

`Schema design` · `Data cleaning` · `Aggregation (GROUP BY / HAVING)` ·
`CASE segmentation` · `CTEs` · `Window functions (RANK, NTILE, running SUM)` ·
`Views` · `Subqueries` · `Business-oriented insight writing`

## How to Run

```bash
createdb zepto_analytics
psql -d zepto_analytics -f zepto_data_analytics.sql
```

Then load the CSV before running Section 2 onward:

```sql
\copy zepto(category, name, mrp, discountPercent, availableQuantity,
            discountedSellingPrice, weightInGms, outOfStock, quantity)
FROM 'zepto_v2.csv' WITH (FORMAT csv, HEADER true);
```

## Sample Insight Framing

> *Category X accounts for ~18% of total estimated inventory value but has
> a stock-out rate of 22% — nearly double the platform average — indicating
> either under-forecasted demand or a supply bottleneck worth investigating
> before the next promotional cycle.*

(Replace with your actual output once you run the script against the dataset.)

## Author's Note

This project is designed to be read start-to-finish as a portfolio piece:
each section builds on the last, comments explain *why* a query exists (not
just what it does), and the final KPI view + business-question section tie
the raw SQL back to decisions a stakeholder could act on.
