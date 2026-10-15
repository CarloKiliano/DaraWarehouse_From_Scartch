/*
===============================================================================
 revision_plata.sql
 Revisiones de calidad después de cargar la capa PLATA
===============================================================================
 ¿Cómo se lee?
   La primera consulta es un "tablero" de pruebas. Cada fila es una
   revisión: da un número (filas o problemas encontrados) y lo compara con lo
   esperado. Si todo salió bien, la columna 'resultado' dice OK en todas.

   Casi todas esperan 0 valor. La excepción es "fechas de pedido
   nulas" = 19: esas fechas venían rotas en el CSV (0 o 5489) y decidimos
   dejarlas en NULL en lugar de inventarlas.

   Las demás consultas sirven para VER los valores estandarizados.
===============================================================================
*/

USE almacen_datos;
GO

SELECT tabla, prueba, valor, esperado,
       CASE WHEN valor = esperado THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (
    -- Conteo de filas ------------------------------------------------------
    SELECT 'crm_cust_info' AS tabla, 'filas cargadas' AS prueba,
           (SELECT COUNT(*) FROM plata.crm_cust_info) AS valor, 18484 AS esperado
    UNION ALL SELECT 'crm_prd_info', 'filas cargadas',
           (SELECT COUNT(*) FROM plata.crm_prd_info), 397
    UNION ALL SELECT 'crm_sales_details', 'filas cargadas',
           (SELECT COUNT(*) FROM plata.crm_sales_details), 60398
    UNION ALL SELECT 'erp_cust_az12', 'filas cargadas',
           (SELECT COUNT(*) FROM plata.erp_cust_az12), 18484
    UNION ALL SELECT 'erp_loc_a101', 'filas cargadas',
           (SELECT COUNT(*) FROM plata.erp_loc_a101), 18484
    UNION ALL SELECT 'erp_px_cat_g1v2', 'filas cargadas',
           (SELECT COUNT(*) FROM plata.erp_px_cat_g1v2), 37

    -- Clientes (CRM) -------------------------------------------------------
    UNION ALL SELECT 'crm_cust_info', 'cst_id nulo o duplicado',
           (SELECT COUNT(*) FROM (
                SELECT cst_id FROM plata.crm_cust_info
                GROUP BY cst_id HAVING COUNT(*) > 1 OR cst_id IS NULL) AS x), 0
    UNION ALL SELECT 'crm_cust_info', 'espacios de mas en nombre o apellido',
           (SELECT COUNT(*) FROM plata.crm_cust_info
            WHERE cst_firstname <> TRIM(cst_firstname)
               OR cst_lastname  <> TRIM(cst_lastname)), 0
    UNION ALL SELECT 'crm_cust_info', 'estado civil fuera de la lista',
           (SELECT COUNT(*) FROM plata.crm_cust_info
            WHERE cst_marital_status NOT IN (N'Soltero', N'Casado', N'n/d')), 0
    UNION ALL SELECT 'crm_cust_info', 'genero fuera de la lista',
           (SELECT COUNT(*) FROM plata.crm_cust_info
            WHERE cst_gndr NOT IN (N'Masculino', N'Femenino', N'n/d')), 0

    -- Productos (CRM) ------------------------------------------------------
    UNION ALL SELECT 'crm_prd_info', 'prd_id nulo o duplicado',
           (SELECT COUNT(*) FROM (
                SELECT prd_id FROM plata.crm_prd_info
                GROUP BY prd_id HAVING COUNT(*) > 1 OR prd_id IS NULL) AS x), 0
    UNION ALL SELECT 'crm_prd_info', 'costo nulo o negativo',
           (SELECT COUNT(*) FROM plata.crm_prd_info
            WHERE prd_cost IS NULL OR prd_cost < 0), 0
    UNION ALL SELECT 'crm_prd_info', 'fecha fin antes de fecha inicio',
           (SELECT COUNT(*) FROM plata.crm_prd_info
            WHERE prd_end_dt < prd_start_dt), 0
    UNION ALL SELECT 'crm_prd_info', 'mas de una version vigente por producto',
           (SELECT COUNT(*) FROM (
                SELECT prd_key FROM plata.crm_prd_info
                WHERE prd_end_dt IS NULL
                GROUP BY prd_key HAVING COUNT(*) > 1) AS x), 0

    -- Ventas (CRM) ---------------------------------------------------------
    UNION ALL SELECT 'crm_sales_details', 'fechas de pedido nulas (venian rotas)',
           (SELECT COUNT(*) FROM plata.crm_sales_details
            WHERE sls_order_dt IS NULL), 19
    UNION ALL SELECT 'crm_sales_details', 'pedido despues del envio o vencimiento',
           (SELECT COUNT(*) FROM plata.crm_sales_details
            WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt), 0
    UNION ALL SELECT 'crm_sales_details', 'ventas <> cantidad x precio',
           (SELECT COUNT(*) FROM plata.crm_sales_details
            WHERE sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
               OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
               OR sls_sales <> sls_quantity * sls_price), 0

    -- ERP ------------------------------------------------------------------
    UNION ALL SELECT 'erp_cust_az12', 'id con prefijo NAS',
           (SELECT COUNT(*) FROM plata.erp_cust_az12 WHERE cid LIKE 'NAS%'), 0
    UNION ALL SELECT 'erp_cust_az12', 'fecha de nacimiento en el futuro',
           (SELECT COUNT(*) FROM plata.erp_cust_az12
            WHERE bdate > CAST(GETDATE() AS DATE)), 0
    UNION ALL SELECT 'erp_cust_az12', 'genero fuera de la lista',
           (SELECT COUNT(*) FROM plata.erp_cust_az12
            WHERE gen NOT IN (N'Masculino', N'Femenino', N'n/d')), 0
    UNION ALL SELECT 'erp_loc_a101', 'id con guion',
           (SELECT COUNT(*) FROM plata.erp_loc_a101 WHERE cid LIKE '%-%'), 0

    -- Integración: ¿los ids del ERP ya coinciden con el CRM? --------------
    UNION ALL SELECT 'erp_cust_az12', 'clientes que no existen en el CRM',
           (SELECT COUNT(*) FROM plata.erp_cust_az12
            WHERE cid NOT IN (SELECT cst_key FROM plata.crm_cust_info)), 0
    UNION ALL SELECT 'erp_loc_a101', 'clientes que no existen en el CRM',
           (SELECT COUNT(*) FROM plata.erp_loc_a101
            WHERE cid NOT IN (SELECT cst_key FROM plata.crm_cust_info)), 0
    UNION ALL SELECT 'crm_sales_details', 'ventas de clientes que no existen',
           (SELECT COUNT(*) FROM plata.crm_sales_details
            WHERE sls_cust_id NOT IN (SELECT cst_id FROM plata.crm_cust_info)), 0
) AS revisiones;

-- Valores estandarizados: así quedaron los códigos traducidos ---------------
SELECT cst_marital_status, COUNT(*) AS clientes FROM plata.crm_cust_info GROUP BY cst_marital_status;
SELECT cst_gndr,           COUNT(*) AS clientes FROM plata.crm_cust_info GROUP BY cst_gndr;
SELECT prd_line,           COUNT(*) AS productos FROM plata.crm_prd_info GROUP BY prd_line;
SELECT gen,                COUNT(*) AS clientes FROM plata.erp_cust_az12 GROUP BY gen;
SELECT cntry,              COUNT(*) AS clientes FROM plata.erp_loc_a101 GROUP BY cntry ORDER BY clientes DESC;
