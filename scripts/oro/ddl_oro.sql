/*
===============================================================================
 ddl_oro.sql
 Crea las VISTAS de la capa ORO (el esquema estrella)
===============================================================================
 ¿Qué hace este script?
   Crea 3 vistas que forman un ESQUEMA ESTRELLA:

                      ┌──────────────────┐
                      │ oro.dim_clientes │
                      └────────┬─────────┘
                               │ cliente_llave
                      ┌────────┴─────────┐
                      │  oro.fact_ventas │
                      └────────┬─────────┘
                               │ producto_llave
                      ┌────────┴──────────┐
                      │ oro.dim_productos │
                      └───────────────────┘

 Nota para mí:
   - DIMENSIÓN: describe el "quién / qué / dónde" (clientes, productos).
   - HECHOS: los eventos que medimos (cada venta) con sus números
     (monto, cantidad, precio) y las llaves para unirlos a las dimensiones.
   - VISTA: una consulta guardada con nombre. No guarda datos, los calcula
     cada vez que la consultas a partir de plata. Por eso oro no necesita
     procedimiento de carga: siempre está al día con plata.
   - LLAVE SUSTITUTA (cliente_llave, producto_llave): un número consecutivo
     que inventamos nosotros con ROW_NUMBER(). Así el modelo no depende de
     los ids de los sistemas fuente (que pueden cambiar o repetirse).

 Aquí ya usamos nombres de negocio en español, porque es la capa que van
 a consultar los analistas.
===============================================================================
*/

USE almacen_datos;
GO

-------------------------------------------------------------------------------
-- oro.dim_clientes
-------------------------------------------------------------------------------
-- Junta la información del cliente que está repartida en 3 tablas:
--   CRM  crm_cust_info  → nombre, apellido, estado civil, género, fecha de alta
--   ERP  erp_cust_az12  → fecha de nacimiento (y género de respaldo)
--   ERP  erp_loc_a101   → país
--
-- Usamos LEFT JOIN: el CRM es la tabla principal; si un cliente no aparece
-- en el ERP, no lo perdemos, solo quedan vacíos esos datos.
--
-- ¿Y si el género no coincide entre CRM y ERP?
--   Regla: el CRM es la fuente principal. Solo si el CRM no lo sabe ('n/d')
--   usamos el del ERP.
CREATE OR ALTER VIEW oro.dim_clientes AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id)  AS cliente_llave,
    ci.cst_id                               AS cliente_id,
    ci.cst_key                              AS numero_cliente,
    ci.cst_firstname                        AS nombre,
    ci.cst_lastname                         AS apellido,
    COALESCE(la.cntry, N'n/d')              AS pais,
    ci.cst_marital_status                   AS estado_civil,
    CASE
        WHEN ci.cst_gndr <> N'n/d' THEN ci.cst_gndr     -- manda el CRM
        ELSE COALESCE(ca.gen, N'n/d')                   -- respaldo: ERP
    END                                     AS genero,
    ca.bdate                                AS fecha_nacimiento,
    ci.cst_create_date                      AS fecha_alta
FROM plata.crm_cust_info AS ci
LEFT JOIN plata.erp_cust_az12 AS ca
       ON ci.cst_key = ca.cid
LEFT JOIN plata.erp_loc_a101 AS la
       ON ci.cst_key = la.cid;
GO

-------------------------------------------------------------------------------
-- oro.dim_productos
-------------------------------------------------------------------------------
-- Junta el producto (CRM) con su categoría (ERP).
--
-- Solo dejamos la versión VIGENTE de cada producto (prd_end_dt IS NULL).
-- Recuerda que en plata un producto puede tener varias versiones con
-- distinto costo; el requisito dice que no guardamos historial.
--
-- Ojo: la categoría 'CO_PE' existe en el CRM pero no en el ERP, así que
-- esos productos quedan con categoría 'n/d'.
CREATE OR ALTER VIEW oro.dim_productos AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS producto_llave,
    pn.prd_id                               AS producto_id,
    pn.prd_key                              AS numero_producto,
    pn.prd_nm                               AS nombre_producto,
    pn.cat_id                               AS categoria_id,
    COALESCE(pc.cat, N'n/d')                AS categoria,
    COALESCE(pc.subcat, N'n/d')             AS subcategoria,
    COALESCE(pc.maintenance, N'n/d')        AS requiere_mantenimiento,
    pn.prd_cost                             AS costo,
    pn.prd_line                             AS linea_producto,
    pn.prd_start_dt                         AS fecha_inicio
FROM plata.crm_prd_info AS pn
LEFT JOIN plata.erp_px_cat_g1v2 AS pc
       ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;        -- solo la versión vigente
GO

-------------------------------------------------------------------------------
-- oro.fact_ventas
-------------------------------------------------------------------------------
-- Cada fila es una línea de venta (un producto dentro de una orden).
-- Cambiamos los ids de los sistemas fuente por nuestras llaves sustitutas
-- buscándolas en las dimensiones.
CREATE OR ALTER VIEW oro.fact_ventas AS
SELECT
    sd.sls_ord_num                          AS numero_orden,
    pr.producto_llave,
    cu.cliente_llave,
    sd.sls_order_dt                         AS fecha_pedido,
    sd.sls_ship_dt                          AS fecha_envio,
    sd.sls_due_dt                           AS fecha_vencimiento,
    sd.sls_sales                            AS monto_venta,
    sd.sls_quantity                         AS cantidad,
    sd.sls_price                            AS precio
FROM plata.crm_sales_details AS sd
LEFT JOIN oro.dim_productos AS pr
       ON sd.sls_prd_key = pr.numero_producto
LEFT JOIN oro.dim_clientes AS cu
       ON sd.sls_cust_id = cu.cliente_id;
GO
