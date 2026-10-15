# 📚 Catálogo de datos — Capa Oro

La capa oro es la que consultan los analistas. Está organizada como un **esquema estrella**:
una tabla de hechos (`fact_ventas`) rodeada de dimensiones (`dim_clientes`, `dim_productos`).

Todas son **vistas**: se calculan al momento a partir de la capa plata.

> `n/d` = no disponible. Se usa cuando el dato falta en la fuente o no se pudo interpretar.

---

## 1. `oro.dim_clientes`

**Qué es:** un cliente por fila, con sus datos personales y su país.
**Fuentes:** `crm_cust_info` (principal) + `erp_cust_az12` + `erp_loc_a101`.
**Filas:** 18,484

| Columna | Tipo | Descripción |
|---|---|---|
| `cliente_llave` | INT | Llave sustituta: número consecutivo generado por el almacén. Es la que usa `fact_ventas`. |
| `cliente_id` | INT | Id numérico del cliente en el CRM. |
| `numero_cliente` | NVARCHAR(50) | Clave alfanumérica del cliente (ej. `AW00011000`). |
| `nombre` | NVARCHAR(50) | Nombre, sin espacios sobrantes. |
| `apellido` | NVARCHAR(50) | Apellido, sin espacios sobrantes. |
| `pais` | NVARCHAR(50) | País de residencia, en español (ej. `Australia`, `Estados Unidos`). |
| `estado_civil` | NVARCHAR(50) | `Casado`, `Soltero` o `n/d`. |
| `genero` | NVARCHAR(50) | `Masculino`, `Femenino` o `n/d`. Manda el CRM; si no lo tiene, se usa el del ERP. |
| `fecha_nacimiento` | DATE | Fecha de nacimiento (AAAA-MM-DD). Las fechas futuras se dejaron en NULL. |
| `fecha_alta` | DATE | Fecha en que el cliente se registró en el CRM. |

---

## 2. `oro.dim_productos`

**Qué es:** un producto por fila, solo en su **versión vigente** (sin historial).
**Fuentes:** `crm_prd_info` (principal) + `erp_px_cat_g1v2`.
**Filas:** 295

| Columna | Tipo | Descripción |
|---|---|---|
| `producto_llave` | INT | Llave sustituta generada por el almacén. Es la que usa `fact_ventas`. |
| `producto_id` | INT | Id numérico del producto en el CRM. |
| `numero_producto` | NVARCHAR(50) | Clave del producto sin el prefijo de categoría (ej. `FR-R92B-58`). |
| `nombre_producto` | NVARCHAR(50) | Nombre descriptivo (incluye tipo, color y talla). |
| `categoria_id` | NVARCHAR(50) | Id de la categoría (ej. `CO_RF`). |
| `categoria` | NVARCHAR(50) | Categoría general (ej. `Bikes`, `Components`). Se deja como viene de la fuente. |
| `subcategoria` | NVARCHAR(50) | Subcategoría (ej. `Road Frames`). Se deja como viene de la fuente. |
| `requiere_mantenimiento` | NVARCHAR(50) | `Sí`, `No` o `n/d`. |
| `costo` | INT | Costo base del producto (los vacíos se pusieron en 0). |
| `linea_producto` | NVARCHAR(50) | `Montaña`, `Ruta`, `Turismo`, `Otras ventas` o `n/d`. |
| `fecha_inicio` | DATE | Desde cuándo está vigente esta versión del producto. |

> Los productos con `categoria_id = 'CO_PE'` quedan con categoría `n/d`, porque esa categoría no existe en el ERP.

---

## 3. `oro.fact_ventas`

**Qué es:** una línea de venta por fila (un producto dentro de una orden).
**Fuente:** `crm_sales_details`.
**Filas:** 60,398

| Columna | Tipo | Descripción |
|---|---|---|
| `numero_orden` | NVARCHAR(50) | Número de la orden de venta (ej. `SO43697`). |
| `producto_llave` | INT | Llave hacia `dim_productos`. |
| `cliente_llave` | INT | Llave hacia `dim_clientes`. |
| `fecha_pedido` | DATE | Cuándo se hizo el pedido. NULL en 19 ventas cuya fecha venía rota. |
| `fecha_envio` | DATE | Cuándo se envió. |
| `fecha_vencimiento` | DATE | Fecha límite de pago. |
| `monto_venta` | INT | Monto total de la línea. Siempre cumple `monto_venta = cantidad × precio`. |
| `cantidad` | INT | Número de piezas. |
| `precio` | INT | Precio por pieza. |

---

## Cómo se unen

```sql
SELECT ...
FROM oro.fact_ventas f
JOIN oro.dim_clientes  c ON f.cliente_llave  = c.cliente_llave
JOIN oro.dim_productos p ON f.producto_llave = p.producto_llave;
```
