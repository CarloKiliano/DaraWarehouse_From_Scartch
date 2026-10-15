/*
===============================================================================
 ddl_plata.sql
 Crea las tablas de la capa PLATA
===============================================================================
 ¿Qué hace este script?
   Crea 6 tablas en el esquema 'plata', una por cada tabla de bronce.
   Si alguna ya existe, la borra y la vuelve a crear.

 ¿En qué se parecen y en qué se diferencian de bronce?
   - Mismos nombres de tablas y columnas (seguimos la regla
     <sistema>_<entidad> y no traducimos lo que viene de la fuente).
   - PERO aquí los datos ya van limpios, así que algunas columnas cambian:
       * crm_prd_info      → nueva columna cat_id (la sacamos de prd_key)
                            y las fechas pasan de DATETIME a DATE.
       * crm_sales_details → las fechas pasan de INT (20101229) a DATE real.
   - Todas llevan una columna extra: dwh_fecha_carga.

 Nota para mí: ¿qué es dwh_fecha_carga?
   Es una COLUMNA TÉCNICA: no viene de los CSV, la agrega el almacén.
   Guarda cuándo se cargó cada fila. Con DEFAULT SYSDATETIME() se llena
   sola, no tenemos que escribirla en el INSERT.
===============================================================================
*/

USE almacen_datos;
GO

-------------------------------------------------------------------------------
-- SISTEMA CRM
-------------------------------------------------------------------------------

IF OBJECT_ID('plata.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE plata.crm_cust_info;
GO

CREATE TABLE plata.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),   -- ahora: 'Casado' / 'Soltero' / 'n/d'
    cst_gndr            NVARCHAR(50),   -- ahora: 'Masculino' / 'Femenino' / 'n/d'
    cst_create_date     DATE,
    dwh_fecha_carga     DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('plata.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE plata.crm_prd_info;
GO

CREATE TABLE plata.crm_prd_info (
    prd_id          INT,
    cat_id          NVARCHAR(50),   -- NUEVA: id de categoría (ej. CO_RF)
    prd_key         NVARCHAR(50),   -- ahora sin el prefijo de categoría
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),   -- ahora: 'Montaña' / 'Ruta' / ...
    prd_start_dt    DATE,           -- antes DATETIME
    prd_end_dt      DATE,           -- antes DATETIME (y recalculada)
    dwh_fecha_carga DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('plata.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE plata.crm_sales_details;
GO

CREATE TABLE plata.crm_sales_details (
    sls_ord_num     NVARCHAR(50),
    sls_prd_key     NVARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    DATE,           -- antes INT
    sls_ship_dt     DATE,           -- antes INT
    sls_due_dt      DATE,           -- antes INT
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT,
    dwh_fecha_carga DATETIME2 DEFAULT SYSDATETIME()
);
GO

-------------------------------------------------------------------------------
-- SISTEMA ERP
-------------------------------------------------------------------------------

IF OBJECT_ID('plata.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE plata.erp_cust_az12;
GO

CREATE TABLE plata.erp_cust_az12 (
    cid             NVARCHAR(50),   -- ahora sin el prefijo 'NAS'
    bdate           DATE,
    gen             NVARCHAR(50),   -- ahora: 'Masculino' / 'Femenino' / 'n/d'
    dwh_fecha_carga DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('plata.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE plata.erp_loc_a101;
GO

CREATE TABLE plata.erp_loc_a101 (
    cid             NVARCHAR(50),   -- ahora sin guion (AW00011000)
    cntry           NVARCHAR(50),   -- ahora en español y estandarizado
    dwh_fecha_carga DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('plata.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE plata.erp_px_cat_g1v2;
GO

CREATE TABLE plata.erp_px_cat_g1v2 (
    id              NVARCHAR(50),
    cat             NVARCHAR(50),
    subcat          NVARCHAR(50),
    maintenance     NVARCHAR(50),   -- ahora: 'Sí' / 'No'
    dwh_fecha_carga DATETIME2 DEFAULT SYSDATETIME()
);
GO
