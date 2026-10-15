/*
===============================================================================
 revision_bronce.sql
 Revisiones rápidas después de cargar la capa BRONCE
===============================================================================
 ¿Para qué?
   Confirmar que cada tabla tiene el mismo número de filas que su CSV
   y darle un primer vistazo a los datos (¡aquí empezarás a ver lo sucios
   que vienen! Eso lo arreglamos en plata).

 Filas esperadas (contadas directamente de los CSV, sin el encabezado):
   crm_cust_info      18,494
   crm_prd_info          397
   crm_sales_details  60,398
   erp_cust_az12      18,484
   erp_loc_a101       18,484
   erp_px_cat_g1v2        37
===============================================================================
*/

USE almacen_datos;
GO

-- 1) Conteo de filas vs. lo esperado
SELECT tabla, filas_cargadas, filas_esperadas,
       CASE WHEN filas_cargadas = filas_esperadas THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (
    SELECT 'crm_cust_info'     AS tabla, (SELECT COUNT(*) FROM bronce.crm_cust_info)     AS filas_cargadas, 18494 AS filas_esperadas
    UNION ALL
    SELECT 'crm_prd_info',      (SELECT COUNT(*) FROM bronce.crm_prd_info),      397
    UNION ALL
    SELECT 'crm_sales_details', (SELECT COUNT(*) FROM bronce.crm_sales_details), 60398
    UNION ALL
    SELECT 'erp_cust_az12',     (SELECT COUNT(*) FROM bronce.erp_cust_az12),     18484
    UNION ALL
    SELECT 'erp_loc_a101',      (SELECT COUNT(*) FROM bronce.erp_loc_a101),      18484
    UNION ALL
    SELECT 'erp_px_cat_g1v2',   (SELECT COUNT(*) FROM bronce.erp_px_cat_g1v2),   37
) AS conteos;

-- 2) Primer vistazo: ¿las columnas cayeron en su lugar?
--    (si ves un nombre en la columna de fecha, algo se recorrió)
SELECT TOP 10 * FROM bronce.crm_cust_info;
SELECT TOP 10 * FROM bronce.crm_prd_info;
SELECT TOP 10 * FROM bronce.crm_sales_details;
SELECT TOP 10 * FROM bronce.erp_cust_az12;
SELECT TOP 10 * FROM bronce.erp_loc_a101;
SELECT TOP 10 * FROM bronce.erp_px_cat_g1v2;
