--1. Lấy 100 dòng đầu tiền
SELECT
    TOP 100 *
FROM
    OPENROWSET(
        BULK 'https://tranghuyen.dfs.core.windows.net/files/sales_data/sales.csv',
        FORMAT = 'CSV',
        HEADER_ROW = TRUE,
        PARSER_VERSION = '2.0'
    ) AS sales

-- 2. Tổng doanh thu theo mỗi đơn hàng
SELECT SalesOrderLineNumber, 
       SUM(Quantity * UnitPrice) AS TotalRevenue
FROM OPENROWSET(
        BULK 'https://tranghuyen.dfs.core.windows.net/files/sales_data/sales.csv',
        FORMAT = 'CSV',
        HEADER_ROW = TRUE,
        PARSER_VERSION = '2.0'
    ) AS sales
GROUP BY SalesOrderLineNumber;


-- 3. Doanh thu theo khách hàng
SELECT CustomerName, 
       SUM(Quantity * UnitPrice) AS TotalRevenue
FROM OPENROWSET(
        BULK 'https://tranghuyen.dfs.core.windows.net/files/sales_data/sales.csv',
        FORMAT = 'CSV',
        HEADER_ROW = TRUE,
        PARSER_VERSION = '2.0'
    ) AS sales
GROUP BY CustomerName;

-- 4. Doanh thu theo tháng
SELECT YEAR(OrderDate) AS Year, 
       MONTH(OrderDate) AS Month, 
       SUM(Quantity * UnitPrice) AS TotalRevenue
FROM OPENROWSET(
        BULK 'https://tranghuyen.dfs.core.windows.net/files/sales_data/sales.csv',
        FORMAT = 'CSV',
        HEADER_ROW = TRUE,
        PARSER_VERSION = '2.0'
    ) AS sales
GROUP BY YEAR(OrderDate), MONTH(OrderDate);



