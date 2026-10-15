/*
===============================================================================
 analisis_exploratorio.sql
 Primeras preguntas de negocio usando la capa ORO
===============================================================================
 ¿Para qué?
   Es la recompensa de todo el trabajo: con el modelo estrella, preguntas
   de negocio se contestan con un par de JOINs. Los requisitos pedían
   información sobre:
     1. Tendencias de ventas
     2. Desempeño de productos
     3. Comportamiento de clientes

 Patrón que se repite:
   fact_ventas (los números)  +  JOIN a una dimensión (el "por qué cosa")
   →  GROUP BY la columna de la dimensión  →  SUM / COUNT / AVG.

 Nota: las 19 ventas sin fecha de pedido no aparecen en los análisis por
 fecha (las filtramos con WHERE fecha_pedido IS NOT NULL).
===============================================================================
*/

USE almacen_datos;
GO

-------------------------------------------------------------------------------
-- 1. TENDENCIAS DE VENTAS
-------------------------------------------------------------------------------

-- 1.1 Ventas, clientes y piezas por año
SELECT
    YEAR(fecha_pedido)              AS anio,
    SUM(monto_venta)                AS ventas_totales,
    COUNT(DISTINCT cliente_llave)   AS clientes,
    SUM(cantidad)                   AS piezas
FROM oro.fact_ventas
WHERE fecha_pedido IS NOT NULL
GROUP BY YEAR(fecha_pedido)
ORDER BY anio;

-- 1.2 Ventas por mes (para ver estacionalidad)
SELECT
    DATETRUNC(MONTH, fecha_pedido)  AS mes,
    SUM(monto_venta)                AS ventas_totales,
    COUNT(DISTINCT numero_orden)    AS ordenes
FROM oro.fact_ventas
WHERE fecha_pedido IS NOT NULL
GROUP BY DATETRUNC(MONTH, fecha_pedido)
ORDER BY mes;

-- 1.3 Ventas acumuladas mes a mes (función de ventana)
SELECT
    mes,
    ventas_totales,
    SUM(ventas_totales) OVER (ORDER BY mes) AS ventas_acumuladas
FROM (
    SELECT DATETRUNC(MONTH, fecha_pedido) AS mes, SUM(monto_venta) AS ventas_totales
    FROM oro.fact_ventas
    WHERE fecha_pedido IS NOT NULL
    GROUP BY DATETRUNC(MONTH, fecha_pedido)
) AS por_mes
ORDER BY mes;

-------------------------------------------------------------------------------
-- 2. DESEMPEÑO DE PRODUCTOS
-------------------------------------------------------------------------------

-- 2.1 Ventas por categoría y su porcentaje del total
SELECT
    p.categoria,
    SUM(f.monto_venta) AS ventas_totales,
    CAST(100.0 * SUM(f.monto_venta) / SUM(SUM(f.monto_venta)) OVER () AS DECIMAL(5,2)) AS porcentaje
FROM oro.fact_ventas AS f
JOIN oro.dim_productos AS p ON f.producto_llave = p.producto_llave
GROUP BY p.categoria
ORDER BY ventas_totales DESC;

-- 2.2 Los 10 productos que más venden
SELECT TOP 10
    p.nombre_producto,
    p.subcategoria,
    SUM(f.monto_venta) AS ventas_totales,
    SUM(f.cantidad)    AS piezas
FROM oro.fact_ventas AS f
JOIN oro.dim_productos AS p ON f.producto_llave = p.producto_llave
GROUP BY p.nombre_producto, p.subcategoria
ORDER BY ventas_totales DESC;

-- 2.3 Margen aproximado por línea de producto (precio de venta vs. costo)
SELECT
    p.linea_producto,
    SUM(f.monto_venta)                         AS ventas_totales,
    SUM(f.cantidad * p.costo)                  AS costo_total,
    SUM(f.monto_venta) - SUM(f.cantidad * p.costo) AS margen_aprox
FROM oro.fact_ventas AS f
JOIN oro.dim_productos AS p ON f.producto_llave = p.producto_llave
GROUP BY p.linea_producto
ORDER BY margen_aprox DESC;

-------------------------------------------------------------------------------
-- 3. COMPORTAMIENTO DE CLIENTES
-------------------------------------------------------------------------------

-- 3.1 Ventas y clientes por país
SELECT
    c.pais,
    COUNT(DISTINCT c.cliente_llave) AS clientes,
    SUM(f.monto_venta)              AS ventas_totales,
    SUM(f.monto_venta) / COUNT(DISTINCT c.cliente_llave) AS venta_por_cliente
FROM oro.fact_ventas AS f
JOIN oro.dim_clientes AS c ON f.cliente_llave = c.cliente_llave
GROUP BY c.pais
ORDER BY ventas_totales DESC;

-- 3.2 Clientes por rango de edad
SELECT
    rango_edad,
    COUNT(*) AS clientes
FROM (
    SELECT
        CASE
            WHEN fecha_nacimiento IS NULL THEN 'n/d'
            WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) < 40 THEN '1) menos de 40'
            WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) < 50 THEN '2) 40 a 49'
            WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) < 60 THEN '3) 50 a 59'
            ELSE '4) 60 o mas'
        END AS rango_edad
    FROM oro.dim_clientes
) AS edades
GROUP BY rango_edad
ORDER BY rango_edad;

-- 3.3 Segmentación simple de clientes por cuánto han gastado
--     (útil para minería de datos: es una primera "etiqueta" de clientes)
SELECT
    segmento,
    COUNT(*)          AS clientes,
    AVG(gasto_total)  AS gasto_promedio
FROM (
    SELECT
        cliente_llave,
        SUM(monto_venta) AS gasto_total,
        CASE
            WHEN SUM(monto_venta) >= 5000 THEN '1) alto (5000+)'
            WHEN SUM(monto_venta) >= 1000 THEN '2) medio (1000 a 4999)'
            ELSE '3) bajo (menos de 1000)'
        END AS segmento
    FROM oro.fact_ventas
    GROUP BY cliente_llave
) AS gasto_por_cliente
GROUP BY segmento
ORDER BY segmento;

-- 3.4 Los 10 mejores clientes
SELECT TOP 10
    c.nombre,
    c.apellido,
    c.pais,
    SUM(f.monto_venta)             AS gasto_total,
    COUNT(DISTINCT f.numero_orden) AS ordenes
FROM oro.fact_ventas AS f
JOIN oro.dim_clientes AS c ON f.cliente_llave = c.cliente_llave
GROUP BY c.cliente_llave, c.nombre, c.apellido, c.pais
ORDER BY gasto_total DESC;
