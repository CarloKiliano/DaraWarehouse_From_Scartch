/*
===============================================================================
 proc_cargar_plata.sql
 Procedimiento que LIMPIA los datos de bronce y los guarda en PLATA
===============================================================================
 ¿Qué hace este script?
   Crea (o actualiza) el procedimiento 'plata.cargar_plata'. Igual que en
   bronce, este script solo guarda la "receta"; para cargar hay que correr:

       EXEC plata.cargar_plata;

 ¿Qué hace el procedimiento?
   Para cada tabla: TRUNCATE (vaciar) → INSERT ... SELECT (leer de bronce,
   limpiar y guardar en plata). Es una carga completa, igual que en bronce.

 Resumen de la limpieza (cada bloque tiene el detalle):
   crm_cust_info      quitar filas basura y duplicados, quitar espacios,
                      traducir códigos (M/S, M/F)
   crm_prd_info       separar categoría y clave, costo vacío → 0,
                      traducir línea de producto, recalcular fecha de fin
   crm_sales_details  convertir fechas numéricas a DATE, corregir montos y
                      precios vacíos, negativos o que no cuadran
   erp_cust_az12      quitar prefijo 'NAS', fechas de nacimiento futuras → NULL,
                      estandarizar género
   erp_loc_a101       quitar guiones del id, estandarizar países
   erp_px_cat_g1v2    quitar espacios, traducir Yes/No

 Nota para mí: valores en español
   Los códigos que NOSOTROS decodificamos (estado civil, género, línea de
   producto, países, mantenimiento) los dejamos en español. Los nombres que
   vienen tal cual de la fuente (nombres de producto, categorías) no se
   traducen porque son "nombres propios" del catálogo de la empresa.
   'n/d' = no disponible (lo usamos cuando el dato falta o no se entiende).

 Nota: las cadenas llevan N delante (N'Montaña') para que SQL Server respete
 acentos y la ñ.
===============================================================================
*/

USE almacen_datos;
GO

CREATE OR ALTER PROCEDURE plata.cargar_plata
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @inicio_total DATETIME2 = SYSDATETIME();
    DECLARE @inicio       DATETIME2;
    DECLARE @filas        INT;
    DECLARE @tabla_actual NVARCHAR(128);

    BEGIN TRY
        PRINT '================================================';
        PRINT ' Cargando la capa PLATA';
        PRINT '================================================';

        PRINT '';
        PRINT '------------------------------------------------';
        PRINT ' Tablas del CRM';
        PRINT '------------------------------------------------';

        -----------------------------------------------------------------------
        -- 1) plata.crm_cust_info  (clientes)
        -----------------------------------------------------------------------
        -- Problemas que encontramos en bronce:
        --   * 4 filas basura sin cst_id (ej. una con cst_key = 'A01Ass')
        --   * clientes repetidos: el mismo cst_id aparece varias veces porque
        --     el registro se fue actualizando. Nos quedamos con el MÁS RECIENTE.
        --   * espacios de más al inicio/final de nombres y apellidos
        --   * estado civil y género vienen como códigos (M, S, F) o vacíos
        --
        -- Truco: ROW_NUMBER() numera las filas de cada cliente (PARTITION BY
        -- cst_id) de la más nueva a la más vieja (ORDER BY fecha DESC).
        -- La fila 1 es la más reciente: esa es la que nos quedamos.
        SET @tabla_actual = N'plata.crm_cust_info';
        SET @inicio = SYSDATETIME();
        PRINT '>> ' + @tabla_actual;

        TRUNCATE TABLE plata.crm_cust_info;

        INSERT INTO plata.crm_cust_info (
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date
        )
        SELECT
            cst_id,
            TRIM(cst_key),
            TRIM(cst_firstname),                       -- quita espacios
            TRIM(cst_lastname),
            CASE UPPER(TRIM(cst_marital_status))
                WHEN 'S' THEN N'Soltero'
                WHEN 'M' THEN N'Casado'
                ELSE N'n/d'
            END,
            CASE UPPER(TRIM(cst_gndr))
                WHEN 'F' THEN N'Femenino'
                WHEN 'M' THEN N'Masculino'
                ELSE N'n/d'
            END,
            cst_create_date
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY cst_id
                       ORDER BY cst_create_date DESC
                   ) AS num_fila
            FROM bronce.crm_cust_info
            WHERE cst_id IS NOT NULL                   -- adiós filas basura
        ) AS clientes_numerados
        WHERE num_fila = 1;                            -- solo la más reciente

        SET @filas = @@ROWCOUNT;
        PRINT CONCAT('   ', @filas, ' filas en ', DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()), ' ms');

        -----------------------------------------------------------------------
        -- 2) plata.crm_prd_info  (productos)
        -----------------------------------------------------------------------
        -- Problemas:
        --   * prd_key mezcla dos datos: 'CO-RF-FR-R92B-58'
        --        primeros 5 caracteres → categoría  'CO-RF' → 'CO_RF'
        --        del 7 en adelante      → clave real 'FR-R92B-58'
        --     (cambiamos '-' por '_' para que coincida con el ERP)
        --   * 2 productos sin costo → ponemos 0
        --   * prd_line viene como código con espacio ('R ', 'M ', ...)
        --   * las fechas de fin están mal: 200 son ANTERIORES a la de inicio.
        --     Regla nueva: un precio/versión termina un día antes de que
        --     empiece la siguiente versión del mismo producto.
        --     LEAD() nos da "el valor de la siguiente fila" dentro del grupo.
        --     Si no hay siguiente versión, queda NULL = sigue vigente.
        SET @tabla_actual = N'plata.crm_prd_info';
        SET @inicio = SYSDATETIME();
        PRINT '>> ' + @tabla_actual;

        TRUNCATE TABLE plata.crm_prd_info;

        INSERT INTO plata.crm_prd_info (
            prd_id, cat_id, prd_key, prd_nm, prd_cost,
            prd_line, prd_start_dt, prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')     AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key))             AS prd_key,
            TRIM(prd_nm),
            ISNULL(prd_cost, 0),                            -- sin costo → 0
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN N'Montaña'
                WHEN 'R' THEN N'Ruta'
                WHEN 'S' THEN N'Otras ventas'
                WHEN 'T' THEN N'Turismo'
                ELSE N'n/d'
            END,
            CAST(prd_start_dt AS DATE),
            DATEADD(DAY, -1,
                LEAD(CAST(prd_start_dt AS DATE)) OVER (
                    PARTITION BY prd_key
                    ORDER BY prd_start_dt
                )
            )                                               AS prd_end_dt
        FROM bronce.crm_prd_info;

        SET @filas = @@ROWCOUNT;
        PRINT CONCAT('   ', @filas, ' filas en ', DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()), ' ms');

        -----------------------------------------------------------------------
        -- 3) plata.crm_sales_details  (ventas)
        -----------------------------------------------------------------------
        -- Problemas:
        --   * las fechas vienen como números (20101229). Algunas son 0 o
        --     tienen menos de 8 dígitos (5489) → no son fechas → NULL.
        --     TRY_CONVERT(..., 112) lee el formato AAAAMMDD; si no puede,
        --     regresa NULL en vez de tronar.
        --   * la regla de negocio es: ventas = cantidad × precio.
        --     - si el monto de venta falta, es negativo/cero o no cuadra
        --       → lo recalculamos como cantidad × |precio|
        --     - si el precio falta o es cero → lo sacamos de ventas / cantidad
        --     - si el precio es negativo → le quitamos el signo (ABS)
        SET @tabla_actual = N'plata.crm_sales_details';
        SET @inicio = SYSDATETIME();
        PRINT '>> ' + @tabla_actual;

        TRUNCATE TABLE plata.crm_sales_details;

        INSERT INTO plata.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id,
            sls_order_dt, sls_ship_dt, sls_due_dt,
            sls_sales, sls_quantity, sls_price
        )
        SELECT
            TRIM(sls_ord_num),
            TRIM(sls_prd_key),
            sls_cust_id,
            CASE WHEN LEN(CAST(sls_order_dt AS VARCHAR(20))) = 8
                 THEN TRY_CONVERT(DATE, CAST(sls_order_dt AS CHAR(8)), 112)
            END                                             AS sls_order_dt,
            CASE WHEN LEN(CAST(sls_ship_dt AS VARCHAR(20))) = 8
                 THEN TRY_CONVERT(DATE, CAST(sls_ship_dt AS CHAR(8)), 112)
            END                                             AS sls_ship_dt,
            CASE WHEN LEN(CAST(sls_due_dt AS VARCHAR(20))) = 8
                 THEN TRY_CONVERT(DATE, CAST(sls_due_dt AS CHAR(8)), 112)
            END                                             AS sls_due_dt,
            CASE
                WHEN sls_sales IS NULL
                  OR sls_sales <= 0
                  OR sls_sales <> sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END                                             AS sls_sales,
            sls_quantity,
            CASE
                WHEN sls_price IS NULL OR sls_price = 0
                THEN sls_sales / NULLIF(sls_quantity, 0)    -- NULLIF evita dividir entre 0
                ELSE ABS(sls_price)
            END                                             AS sls_price
        FROM bronce.crm_sales_details;

        SET @filas = @@ROWCOUNT;
        PRINT CONCAT('   ', @filas, ' filas en ', DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()), ' ms');

        PRINT '';
        PRINT '------------------------------------------------';
        PRINT ' Tablas del ERP';
        PRINT '------------------------------------------------';

        -----------------------------------------------------------------------
        -- 4) plata.erp_cust_az12  (fecha de nacimiento y género)
        -----------------------------------------------------------------------
        -- Problemas:
        --   * muchos ids traen el prefijo 'NAS' (NASAW00011000). Sin él,
        --     el id coincide con cst_key del CRM (AW00011000) y podemos unir.
        --   * 16 fechas de nacimiento en el FUTURO (hasta el año 9999) → NULL
        --   * el género viene de mil formas: 'Male', 'M', 'M ', 'F', ' ', vacío
        SET @tabla_actual = N'plata.erp_cust_az12';
        SET @inicio = SYSDATETIME();
        PRINT '>> ' + @tabla_actual;

        TRUNCATE TABLE plata.erp_cust_az12;

        INSERT INTO plata.erp_cust_az12 (cid, bdate, gen)
        SELECT
            CASE WHEN cid LIKE 'NAS%'
                 THEN SUBSTRING(cid, 4, LEN(cid))           -- quita 'NAS'
                 ELSE cid
            END                                             AS cid,
            CASE WHEN bdate > CAST(GETDATE() AS DATE)
                 THEN NULL                                  -- nadie nace en el futuro
                 ELSE bdate
            END                                             AS bdate,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN N'Femenino'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN N'Masculino'
                ELSE N'n/d'
            END                                             AS gen
        FROM bronce.erp_cust_az12;

        SET @filas = @@ROWCOUNT;
        PRINT CONCAT('   ', @filas, ' filas en ', DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()), ' ms');

        -----------------------------------------------------------------------
        -- 5) plata.erp_loc_a101  (país del cliente)
        -----------------------------------------------------------------------
        -- Problemas:
        --   * el id trae guion (AW-00011000) y en el CRM no (AW00011000)
        --   * un mismo país escrito de varias formas: 'US', 'USA',
        --     'United States'; 'DE' y 'Germany'; vacíos o solo espacios
        SET @tabla_actual = N'plata.erp_loc_a101';
        SET @inicio = SYSDATETIME();
        PRINT '>> ' + @tabla_actual;

        TRUNCATE TABLE plata.erp_loc_a101;

        INSERT INTO plata.erp_loc_a101 (cid, cntry)
        SELECT
            REPLACE(cid, '-', '')                           AS cid,
            CASE
                WHEN cntry IS NULL OR TRIM(cntry) = ''               THEN N'n/d'
                WHEN TRIM(cntry) IN ('US', 'USA', 'United States')   THEN N'Estados Unidos'
                WHEN TRIM(cntry) IN ('DE', 'Germany')                THEN N'Alemania'
                WHEN TRIM(cntry) = 'United Kingdom'                  THEN N'Reino Unido'
                WHEN TRIM(cntry) = 'France'                          THEN N'Francia'
                WHEN TRIM(cntry) = 'Canada'                          THEN N'Canadá'
                WHEN TRIM(cntry) = 'Australia'                       THEN N'Australia'
                ELSE TRIM(cntry)                -- si llega un país nuevo, se queda como viene
            END                                             AS cntry
        FROM bronce.erp_loc_a101;

        SET @filas = @@ROWCOUNT;
        PRINT CONCAT('   ', @filas, ' filas en ', DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()), ' ms');

        -----------------------------------------------------------------------
        -- 6) plata.erp_px_cat_g1v2  (categorías de producto)
        -----------------------------------------------------------------------
        -- Esta tabla viene bastante limpia. Solo quitamos espacios por
        -- precaución y traducimos Yes/No.
        SET @tabla_actual = N'plata.erp_px_cat_g1v2';
        SET @inicio = SYSDATETIME();
        PRINT '>> ' + @tabla_actual;

        TRUNCATE TABLE plata.erp_px_cat_g1v2;

        INSERT INTO plata.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
        SELECT
            TRIM(id),
            TRIM(cat),
            TRIM(subcat),
            CASE UPPER(TRIM(maintenance))
                WHEN 'YES' THEN N'Sí'
                WHEN 'NO'  THEN N'No'
                ELSE N'n/d'
            END
        FROM bronce.erp_px_cat_g1v2;

        SET @filas = @@ROWCOUNT;
        PRINT CONCAT('   ', @filas, ' filas en ', DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()), ' ms');

        PRINT '';
        PRINT '================================================';
        PRINT CONCAT(' Capa PLATA cargada. Tiempo total: ',
                     DATEDIFF(MILLISECOND, @inicio_total, SYSDATETIME()), ' ms');
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '';
        PRINT '================================================';
        PRINT ' ERROR al cargar la capa PLATA';
        PRINT ' Tabla que estaba cargando: ' + ISNULL(@tabla_actual, '(ninguna)');
        PRINT ' Mensaje: ' + ERROR_MESSAGE();
        PRINT ' Numero de error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        PRINT '================================================';
        THROW;
    END CATCH;
END;
GO

-- Para cargar los datos (después de haber cargado bronce):
-- EXEC plata.cargar_plata;
