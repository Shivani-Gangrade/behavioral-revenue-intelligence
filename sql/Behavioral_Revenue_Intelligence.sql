-- ═══════════════════════════════════════════════════════════════════
-- Project  : Behavioral Revenue Intelligence & Customer Strategy Analysis
-- Author   : Shivani Gangrade
-- Tool     : MySQL Workbench
-- Dataset  : 1,000 Customers | 45 Products | 9,644 Transactions
-- Period   : January 2023 – December 2024
-- Stages   : Schema Design → Data Import → Business Analysis
-- ═══════════════════════════════════════════════════════════════════
-- SCHEMA OVERVIEW
-- ┌──────────────────┐       ┌──────────────────┐
-- │  Dim_Customer    │       │   Dim_Product     │
-- │  (1,000 rows)    │       │   (45 rows)       │
-- │  PK: customer_id │       │   PK: product_id  │
-- └────────┬─────────┘       └────────┬──────────┘
--          │                          │
--          └──────────┬───────────────┘
--                     ▼
--          ┌──────────────────────┐
--          │   Fact_Transactions  │
--          │   (9,644 rows)       │
--          │   FK: customer_id    │
--          │   FK: product_id     │
--          └──────────────────────┘
-- ═══════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────
-- SECTION 1: DATABASE & SCHEMA SETUP
-- ───────────────────────────────────────────────────────────────────

-- Create dedicated database for logical separation from other projects
CREATE DATABASE IF NOT EXISTS retail_intelligence;
USE retail_intelligence;


-- Dim_Customer: stores static customer attributes used for segmentation
-- One row per customer — joins to Fact_Transactions on customer_id
CREATE TABLE Dim_Customer (
    customer_id             INT             PRIMARY KEY,   -- Unique customer identifier
    customer_name           VARCHAR(100),                  -- Customer full name
    age                     INT,                           -- Used for demographic segmentation
    age_group               VARCHAR(20),                   -- Pre-engineered: Young Adult / Adult / Middle-aged / Senior
    gender                  VARCHAR(10),                   -- Gender segmentation
    location                VARCHAR(100),                  -- Geographic revenue analysis
    subscription_status     VARCHAR(5),                    -- Retention indicator: Yes / No
    payment_method          VARCHAR(50),                   -- Payment preference insights
    frequency_of_purchases  VARCHAR(50)                    -- Buying cycle: Weekly / Monthly / Quarterly etc.
);


-- Dim_Product: stores product catalog attributes
-- One row per product — joins to Fact_Transactions on product_id
CREATE TABLE Dim_Product (
    product_id   INT           PRIMARY KEY,  -- Surrogate key generated during ETL
    item_name    VARCHAR(100),               -- Product name for item-level analysis
    category     VARCHAR(50)                 -- Category grouping: Clothing / Footwear / Accessories / Outerwear
);


-- Fact_Transactions: core transactional table — one row per purchase event
-- Contains all measurable business metrics (revenue, discounts, ratings)
-- Foreign keys link to both dimension tables forming a Star Schema
CREATE TABLE Fact_Transactions (
    transaction_id      INT             PRIMARY KEY,   -- Unique transaction identifier
    customer_id         INT,                           -- FK → Dim_Customer
    product_id          INT,                           -- FK → Dim_Product
    purchase_date       DATE,                          -- Enables time-series & seasonal analysis
    season              VARCHAR(10),                   -- Spring / Summer / Fall / Winter
    purchase_amount     DECIMAL(10,2),                 -- Core revenue metric (post-discount)
    discount_applied    VARCHAR(5),                    -- Promotion flag: Yes / No
    discount_percentage INT,                           -- Discount depth: 0 / 10 / 15 / 20 / 25 / 30
    promo_code_used     VARCHAR(5),                    -- Promo code usage: Yes / No
    shipping_type       VARCHAR(50),                   -- Delivery preference: Standard / Express / etc.
    review_rating       DECIMAL(3,1),                  -- Customer satisfaction: 1.0 – 5.0
    size_purchased      VARCHAR(5),                    -- Product size: XS / S / M / L / XL
    color_purchased     VARCHAR(30),                   -- Product color for inventory insights
    FOREIGN KEY (customer_id) REFERENCES Dim_Customer(customer_id),
    FOREIGN KEY (product_id)  REFERENCES Dim_Product(product_id)
);


-- ───────────────────────────────────────────────────────────────────
-- SECTION 2: SCHEMA VALIDATION
-- CSV import to confirm row counts and relationships
-- ───────────────────────────────────────────────────────────────────

SELECT COUNT(*) AS customer_count  FROM Dim_Customer;       -- Expected: 1,000
SELECT COUNT(*) AS product_count   FROM Dim_Product;        -- Expected: 45
SELECT COUNT(*) AS transaction_count FROM Fact_Transactions; -- Expected: 9,644

-- Validate JOIN integrity across all 3 tables
SELECT
    c.customer_name,
    c.subscription_status,
    p.item_name,
    p.category,
    t.purchase_date,
    t.purchase_amount
FROM Fact_Transactions t
JOIN Dim_Customer c ON t.customer_id = c.customer_id
JOIN Dim_Product  p ON t.product_id  = p.product_id
LIMIT 10;


-- ───────────────────────────────────────────────────────────────────
-- SECTION 3: REVENUE ANALYSIS
-- ───────────────────────────────────────────────────────────────────

-- Query 1: Business KPI Summary
-- Top-level revenue metrics used as dashboard KPIs
SELECT
    COUNT(transaction_id)            AS total_orders,
    COUNT(DISTINCT customer_id)      AS total_customers,
    ROUND(SUM(purchase_amount), 2)   AS total_revenue,
    ROUND(AVG(purchase_amount), 2)   AS avg_order_value
FROM Fact_Transactions;
-- Finding: Total revenue $855K across 9,644 orders, avg order $88.6


-- Query 2: Monthly Revenue Trend (2023 vs 2024)
-- Tracks month-over-month growth to identify seasonal peaks and declining periods
SELECT
    YEAR(purchase_date)             AS year,
    MONTH(purchase_date)            AS month,
    MONTHNAME(purchase_date)        AS month_name,
    ROUND(SUM(purchase_amount), 2)  AS monthly_revenue,
    COUNT(transaction_id)           AS total_orders
FROM Fact_Transactions
GROUP BY year, month, month_name
ORDER BY year, month;
-- Finding: Revenue peaked in December-January driven by Winter season demand


-- Query 3: Revenue by Product Category
-- Identifies which category drives the most revenue for inventory prioritization
SELECT
    p.category,
    COUNT(t.transaction_id)          AS total_orders,
    ROUND(SUM(t.purchase_amount), 2) AS total_revenue,
    ROUND(AVG(t.purchase_amount), 2) AS avg_order_value
FROM Fact_Transactions t
JOIN Dim_Product p ON t.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;
-- Finding: Outerwear had the highest avg order value despite fewer transactions


-- Query 4: Revenue by Season
-- Measures seasonal demand to support inventory and campaign planning
SELECT
    season,
    ROUND(SUM(purchase_amount), 2)  AS total_revenue,
    COUNT(transaction_id)           AS total_orders,
    ROUND(AVG(purchase_amount), 2)  AS avg_order_value
FROM Fact_Transactions
GROUP BY season
ORDER BY total_revenue DESC;
-- Finding: Winter generated highest revenue — aligns with Outerwear category strength


-- ───────────────────────────────────────────────────────────────────
-- SECTION 4: CUSTOMER SEGMENTATION
-- ───────────────────────────────────────────────────────────────────

-- Query 5: Customer Lifecycle Segmentation using CTE
-- Classifies customers into New / Returning / Loyal based on purchase count
-- CTE computes per-customer summary; outer query applies segmentation logic
WITH customer_summary AS (
    SELECT
        customer_id,
        COUNT(transaction_id)           AS total_orders,
        ROUND(SUM(purchase_amount), 2)  AS total_spent,
        ROUND(AVG(purchase_amount), 2)  AS avg_order_value,
        MIN(purchase_date)              AS first_purchase,
        MAX(purchase_date)              AS last_purchase
    FROM Fact_Transactions
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN total_orders <= 5  THEN 'New'
        WHEN total_orders <= 10 THEN 'Returning'
        ELSE 'Loyal'
    END                             AS customer_segment,
    COUNT(customer_id)              AS total_customers,
    ROUND(AVG(total_spent), 2)      AS avg_lifetime_spend,
    ROUND(AVG(avg_order_value), 2)  AS avg_order_value
FROM customer_summary
GROUP BY customer_segment
ORDER BY avg_lifetime_spend DESC;
-- Finding: Loyal customers (11+ orders) had 3x higher lifetime spend than New customers


-- Query 6: Revenue by Age Group & Gender
-- Demographic revenue breakdown to support targeted marketing strategy
SELECT
    c.age_group,
    c.gender,
    COUNT(t.transaction_id)          AS total_orders,
    ROUND(SUM(t.purchase_amount), 2) AS total_revenue,
    ROUND(AVG(t.purchase_amount), 2) AS avg_order_value
FROM Fact_Transactions t
JOIN Dim_Customer c ON t.customer_id = c.customer_id
GROUP BY c.age_group, c.gender
ORDER BY total_revenue DESC;
-- Finding: Middle Aged females contributed the highest total revenue segment


-- Query 7: Top 10 High Value Customers
-- Identifies VIP customers by lifetime spend for loyalty program targeting
SELECT
    c.customer_id,
    c.customer_name,
    c.subscription_status,
    c.location,
    COUNT(t.transaction_id)          AS total_orders,
    ROUND(SUM(t.purchase_amount), 2) AS lifetime_spend,
    ROUND(AVG(t.purchase_amount), 2) AS avg_order_value
FROM Fact_Transactions t
JOIN Dim_Customer c ON t.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.subscription_status, c.location
ORDER BY lifetime_spend DESC
LIMIT 10;
-- Finding: Most of the customers in top 10 by lifetime spend held active subscriptions


-- ───────────────────────────────────────────────────────────────────
-- SECTION 5: SUBSCRIPTION & RETENTION ANALYSIS
-- ───────────────────────────────────────────────────────────────────

-- Query 8: Subscriber vs Non-Subscriber Behavior
-- Measures whether subscription status drives higher revenue and order frequency
SELECT
    c.subscription_status,
    COUNT(DISTINCT c.customer_id)    AS total_customers,
    COUNT(t.transaction_id)          AS total_orders,
    ROUND(SUM(t.purchase_amount), 2) AS total_revenue,
    ROUND(AVG(t.purchase_amount), 2) AS avg_order_value,
    ROUND(COUNT(t.transaction_id) /
          COUNT(DISTINCT c.customer_id), 1) AS avg_orders_per_customer
FROM Dim_Customer c
JOIN Fact_Transactions t ON c.customer_id = t.customer_id
GROUP BY c.subscription_status;
-- Finding: Subscribers placed 1.06x more orders on average than non-subscribers


-- Query 9: Subscription Rate by Age Group
-- Identifies which demographic converts to subscription most — informs acquisition strategy
SELECT
    age_group,
    COUNT(customer_id)               AS total_customers,
    SUM(CASE WHEN subscription_status = 'Yes' THEN 1 ELSE 0 END) AS subscribers,
    ROUND(
        SUM(CASE WHEN subscription_status = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(customer_id) * 100, 1
    )                                AS subscription_rate_pct
FROM Dim_Customer
GROUP BY age_group
ORDER BY subscription_rate_pct DESC;
-- Finding: Adults (26–40) had highest subscription rate at 58.1% — prime retention target


-- ───────────────────────────────────────────────────────────────────
-- SECTION 6: DISCOUNT & PRICING INTELLIGENCE
-- ───────────────────────────────────────────────────────────────────

-- Query 10: Discount Impact on Revenue
-- Compares average spend between discounted and non-discounted orders
-- Answers: does discounting attract higher spend or indicate margin pressure?
SELECT
    discount_applied,
    COUNT(transaction_id)            AS total_orders,
    ROUND(SUM(purchase_amount), 2)   AS total_revenue,
    ROUND(AVG(purchase_amount), 2)   AS avg_order_value
FROM Fact_Transactions
GROUP BY discount_applied;
-- Finding: Discounted orders had lower avg value but represented 40% of total revenue


-- Query 11: Discount Dependency by Category
-- High discount % = weak organic demand or price-sensitive customer base
SELECT
    p.category,
    COUNT(t.transaction_id)          AS total_orders,
    SUM(CASE WHEN t.discount_applied = 'Yes' THEN 1 ELSE 0 END) AS discounted_orders,
    ROUND(
        SUM(CASE WHEN t.discount_applied = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(t.transaction_id) * 100, 1
    )                                AS discount_dependency_pct
FROM Fact_Transactions t
JOIN Dim_Product p ON t.product_id = p.product_id
GROUP BY p.category
ORDER BY discount_dependency_pct DESC;
-- Finding: Footwear showed highest discount dependency — may signal pricing issues


-- Query 12: Revenue Leakage from Discounts (CTE)
-- Quantifies exactly how much revenue is lost at each discount tier
-- Helps finance teams evaluate whether discount bands are profitable
WITH discount_analysis AS (
    SELECT
        discount_percentage,
        COUNT(transaction_id)           AS total_orders,
        ROUND(SUM(purchase_amount), 2)  AS actual_revenue,
        ROUND(SUM(purchase_amount /
            (1 - discount_percentage / 100.0)), 2) AS revenue_without_discount
    FROM Fact_Transactions
    WHERE discount_applied = 'Yes'
    GROUP BY discount_percentage
)
SELECT
    discount_percentage,
    total_orders,
    actual_revenue,
    revenue_without_discount,
    ROUND(revenue_without_discount - actual_revenue, 2) AS revenue_lost
FROM discount_analysis
ORDER BY discount_percentage;
-- Finding: 30% discount tier caused the highest revenue leakage at $26581.80


-- ───────────────────────────────────────────────────────────────────
-- SECTION 7: PRODUCT PERFORMANCE
-- ───────────────────────────────────────────────────────────────────

-- Query 13: Top 10 Products by Revenue
-- Identifies bestsellers combining revenue, order volume and customer satisfaction
SELECT
    p.item_name,
    p.category,
    COUNT(t.transaction_id)          AS total_orders,
    ROUND(SUM(t.purchase_amount), 2) AS total_revenue,
    ROUND(AVG(t.review_rating), 2)   AS avg_rating
FROM Fact_Transactions t
JOIN Dim_Product p ON t.product_id = p.product_id
GROUP BY p.item_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;
-- Finding: Leather Jacket and Watch consistently ranked top 3 across revenue and rating


-- Query 14: Top 3 Products Per Category (Window Function — DENSE_RANK)
-- Category-level merchandising intelligence for inventory and marketing decisions
-- DENSE_RANK ensures tied products are both included rather than arbitrarily excluded
SELECT category, item_name, total_revenue, revenue_rank
FROM (
    SELECT
        p.category,
        p.item_name,
        ROUND(SUM(t.purchase_amount), 2) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY p.category
            ORDER BY SUM(t.purchase_amount) DESC
        ) AS revenue_rank
    FROM Fact_Transactions t
    JOIN Dim_Product p ON t.product_id = p.product_id
    GROUP BY p.category, p.item_name
) ranked
WHERE revenue_rank <= 3
ORDER BY category, revenue_rank;
-- Finding: Within Footwear, Boots and Running Shoes drove 60%+ of category revenue


-- Query 15: Shipping Type vs Average Spend
-- Tests whether premium shipping customers are also higher spenders
-- Useful for logistics cost vs revenue optimization decisions
SELECT
    shipping_type,
    COUNT(transaction_id)            AS total_orders,
    ROUND(AVG(purchase_amount), 2)   AS avg_order_value,
    ROUND(SUM(purchase_amount), 2)   AS total_revenue
FROM Fact_Transactions
GROUP BY shipping_type
ORDER BY avg_order_value DESC;
-- Finding: Next Day Air customers had highest avg spend — suggests premium buyer behavior


