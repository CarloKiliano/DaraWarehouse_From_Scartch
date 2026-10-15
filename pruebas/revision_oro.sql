/*
===============================================================================
 revision_oro.sql
 Revisiones de calidad de la capa ORO (el esquema estrella)
===============================================================================
 ¿Qué revisamos?
   - Que cada llave sustituta sea única (si se repite, al unir las tablas
     las ventas se duplicarían y los totales saldrían inflados).
   - Que ninguna venta quede "huérfana" (sin cliente o sin producto).
   - Que los totales coincidan con lo que calculamos de los datos limpios.

 Igual que en plata: si todo está bien, todas las filas dicen OK.
===============================================================================
*/

USE almacen_datos;
GO

SELECT vista, prueba, valor, esperado,
       CASE WHEN valor = esperado THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM (
    -- Conteos --------------------------------------------------------------
    SELECT 'dim_clientes' AS vista, 'filas' AS prueba,
           CAST((SELECT COUNT(*) FROM oro.dim_clientes) AS BIGINT) AS valor,
           CAST(18484 AS BIGINT) AS esperado
    UNION ALL SELECT 'dim_productos', 'filas (solo versiones vigentes)',
           (SELECT COUNT(*) FROM oro.dim_productos), 295
    UNION ALL SELECT 'fact_ventas', 'filas',
           (SELECT COUNT(*) FROM oro.fact_ventas), 60398

    -- Llaves únicas --------------------------------------------------------
    UNION ALL SELECT 'dim_clientes', 'cliente_llave repetida',
           (SELECT COUNT(*) FROM (SELECT cliente_llave FROM oro.dim_clientes
                                  GROUP BY cliente_llave HAVING COUNT(*) > 1) AS x), 0
    UNION ALL SELECT 'dim_clientes', 'cliente_id repetido',
           (SELECT COUNT(*) FROM (SELECT cliente_id FROM oro.dim_clientes
                                  GROUP BY cliente_id HAVING COUNT(*) > 1) AS x), 0
    UNION ALL SELECT 'dim_productos', 'producto_llave repetida',
           (SELECT COUNT(*) FROM (SELECT producto_llave FROM oro.dim_productos
                                  GROUP BY producto_llave HAVING COUNT(*) > 1) AS x), 0
    UNION ALL SELECT 'dim_productos', 'numero_producto repetido',
           (SELECT COUNT(*) FROM (SELECT numero_producto FROM oro.dim_productos
                                  GROUP BY numero_producto HAVING COUNT(*) > 1) AS x), 0

    -- Integridad: cada venta debe encontrar su cliente y su producto ------
    UNION ALL SELECT 'fact_ventas', 'ventas sin cliente',
           (SELECT COUNT(*) FROM oro.fact_ventas WHERE cliente_llave IS NULL), 0
    UNION ALL SELECT 'fact_ventas', 'ventas sin producto',
           (SELECT COUNT(*) FROM oro.fact_ventas WHERE producto_llave IS NULL), 0
    UNION ALL SELECT 'fact_ventas', 'monto <> cantidad x precio',
           (SELECT COUNT(*) FROM oro.fact_ventas WHERE monto_venta <> cantidad * precio), 0

    -- Totales de control ---------------------------------------------------
    UNION ALL SELECT 'fact_ventas', 'suma de monto_venta',
           (SELECT SUM(CAST(monto_venta AS BIGINT)) FROM oro.fact_ventas), 29356250
    UNION ALL SELECT 'fact_ventas', 'suma de cantidad',
           (SELECT SUM(CAST(cantidad AS BIGINT)) FROM oro.fact_ventas), 60423
) AS revisiones;

-- Vistazo a cada vista -------------------------------------------------------
SELECT TOP 10 * FROM oro.dim_clientes;
SELECT TOP 10 * FROM oro.dim_productos;
SELECT TOP 10 * FROM oro.fact_ventas;

-- ¿Cómo quedó el género después de combinar CRM + ERP? -----------------------
-- (en plata el CRM tenía 4,569 'n/d'; con el respaldo del ERP bajan a 15)
SELECT genero, COUNT(*) AS clientes FROM oro.dim_clientes GROUP BY genero;
