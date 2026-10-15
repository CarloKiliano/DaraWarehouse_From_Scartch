/*
===============================================================================
 ddl_bronce.sql
 Crea las tablas de la capa BRONCE
===============================================================================
 ¿Qué hace este script?
   Crea 6 tablas vacías en el esquema 'bronce', una por cada archivo CSV.
   Si alguna ya existe, la borra y la vuelve a crear.

 Ideas clave de la capa bronce:
   - Es una COPIA EXACTA de los archivos. Aquí no limpiamos nada.
   - Por eso los nombres de tablas y columnas son los mismos que en los CSV
     (en inglés, como vienen del sistema). Formato: <sistema>_<entidad>.
   - Si en plata encontramos un dato raro, podemos regresar aquí y ver
     cómo venía originalmente.

 Nota para mí sobre los tipos de dato:
   - INT          → números enteros
   - NVARCHAR(50) → texto de hasta 50 caracteres (la N permite acentos y
                    caracteres especiales)
   - DATE         → solo fecha (año-mes-día)
   - DATETIME     → fecha y hora

   ¿Por qué las fechas de ventas son INT? Porque en el CSV vienen como
   números tipo 20101229. Las guardamos así en bronce y las convertimos a
   fecha real en plata.

 DDL = Data Definition Language: las instrucciones que DEFINEN la estructura
 (CREATE, DROP, ALTER), no las que mueven datos.
===============================================================================
*/

USE almacen_datos;
GO

-------------------------------------------------------------------------------
-- SISTEMA CRM
-------------------------------------------------------------------------------

-- Clientes (archivo: source_crm/cust_info.csv)
IF OBJECT_ID('bronce.crm_cust_info', 'U') IS NOT NULL   -- 'U' = tabla de usuario
    DROP TABLE bronce.crm_cust_info;
GO

CREATE TABLE bronce.crm_cust_info (
    cst_id              INT,            -- id numérico del cliente
    cst_key             NVARCHAR(50),   -- clave del cliente (ej. AW00011000)
    cst_firstname       NVARCHAR(50),   -- nombre
    cst_lastname        NVARCHAR(50),   -- apellido
    cst_marital_status  NVARCHAR(50),   -- estado civil (M / S)
    cst_gndr            NVARCHAR(50),   -- género (M / F)
    cst_create_date     DATE            -- fecha de alta del cliente
);
GO

-- Productos (archivo: source_crm/prd_info.csv)
IF OBJECT_ID('bronce.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronce.crm_prd_info;
GO

CREATE TABLE bronce.crm_prd_info (
    prd_id          INT,            -- id numérico del producto
    prd_key         NVARCHAR(50),   -- clave del producto (incluye la categoría)
    prd_nm          NVARCHAR(50),   -- nombre del producto
    prd_cost        INT,            -- costo
    prd_line        NVARCHAR(50),   -- línea de producto (R, M, S, T)
    prd_start_dt    DATETIME,       -- desde cuándo está vigente
    prd_end_dt      DATETIME        -- hasta cuándo estuvo vigente
);
GO

-- Detalle de ventas (archivo: source_crm/sales_details.csv)
IF OBJECT_ID('bronce.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronce.crm_sales_details;
GO

CREATE TABLE bronce.crm_sales_details (
    sls_ord_num     NVARCHAR(50),   -- número de orden (ej. SO43697)
    sls_prd_key     NVARCHAR(50),   -- producto vendido
    sls_cust_id     INT,            -- cliente que compró
    sls_order_dt    INT,            -- fecha de pedido   (viene como 20101229)
    sls_ship_dt     INT,            -- fecha de envío    (mismo formato)
    sls_due_dt      INT,            -- fecha de vencimiento (mismo formato)
    sls_sales       INT,            -- monto total de la venta
    sls_quantity    INT,            -- cantidad de piezas
    sls_price       INT             -- precio unitario
);
GO

-------------------------------------------------------------------------------
-- SISTEMA ERP
-------------------------------------------------------------------------------

-- Datos extra de clientes (archivo: source_erp/CUST_AZ12.csv)
IF OBJECT_ID('bronce.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronce.erp_cust_az12;
GO

CREATE TABLE bronce.erp_cust_az12 (
    cid     NVARCHAR(50),   -- id del cliente (ej. NASAW00011000)
    bdate   DATE,           -- fecha de nacimiento
    gen     NVARCHAR(50)    -- género
);
GO

-- Ubicación de clientes (archivo: source_erp/LOC_A101.csv)
IF OBJECT_ID('bronce.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronce.erp_loc_a101;
GO

CREATE TABLE bronce.erp_loc_a101 (
    cid     NVARCHAR(50),   -- id del cliente (ej. AW-00011000)
    cntry   NVARCHAR(50)    -- país
);
GO

-- Categorías de productos (archivo: source_erp/PX_CAT_G1V2.csv)
IF OBJECT_ID('bronce.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronce.erp_px_cat_g1v2;
GO

CREATE TABLE bronce.erp_px_cat_g1v2 (
    id          NVARCHAR(50),   -- id de la categoría (ej. AC_BR)
    cat         NVARCHAR(50),   -- categoría
    subcat      NVARCHAR(50),   -- subcategoría
    maintenance NVARCHAR(50)    -- ¿requiere mantenimiento? (Yes / No)
);
GO
