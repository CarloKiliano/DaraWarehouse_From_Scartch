# 📏 Convenciones de nombres

Reglas para que todo el proyecto se vea igual y cualquiera lo entienda.
Basadas en las del proyecto original, adaptadas al español.

## Reglas generales

- **Siempre `snake_case`**: minúsculas y palabras separadas con guion bajo (`fecha_nacimiento`, no `FechaNacimiento`).
- **Español** en todo lo que nombramos nosotros (esquemas, vistas, columnas de oro, procedimientos, archivos).
- **Sin acentos ni ñ** en nombres de objetos (`anio`, no `año`) para evitar problemas de codificación.
- No usar palabras reservadas de SQL como nombres (`date`, `user`, `order`...).

## Base de datos y esquemas

| Objeto | Nombre |
|---|---|
| Base de datos | `almacen_datos` |
| Esquema capa 1 | `bronce` |
| Esquema capa 2 | `plata` |
| Esquema capa 3 | `oro` |

## Tablas

### Bronce y plata → `<sistema_fuente>_<entidad>`

Aquí **no traducimos**: el nombre de la tabla y de sus columnas se copia tal cual del sistema
fuente. Así es fácil saber de qué archivo vino cada dato.

- `<sistema_fuente>`: `crm` o `erp`
- `<entidad>`: nombre exacto del archivo, en minúsculas
- Ejemplos: `bronce.crm_cust_info`, `bronce.erp_loc_a101`, `plata.crm_sales_details`

### Oro → `<categoria>_<entidad>`

Aquí sí usamos nombres de negocio en español, porque es la capa que ven los analistas.

| Prefijo | Significado | Ejemplo |
|---|---|---|
| `dim_` | Tabla/vista de dimensión (el "quién, qué, dónde") | `oro.dim_clientes`, `oro.dim_productos` |
| `fact_` | Tabla/vista de hechos (los eventos medibles) | `oro.fact_ventas` |
| `report_` | Vista de reporte | `oro.report_ventas_mensuales` |

## Columnas

| Tipo | Regla | Ejemplo |
|---|---|---|
| Llave sustituta (oro) | `<entidad>_llave` | `cliente_llave`, `producto_llave` |
| Columna técnica (la agrega el almacén, no viene de la fuente) | prefijo `dwh_` | `dwh_fecha_carga` |
| Columnas de oro | español, descriptivas | `nombre`, `pais`, `fecha_pedido` |

## Procedimientos almacenados

- Formato: `cargar_<capa>`
- Ejemplos: `bronce.cargar_bronce`, `plata.cargar_plata`

## Archivos de scripts

| Tipo | Formato | Ejemplo |
|---|---|---|
| Creación de tablas | `ddl_<capa>.sql` | `ddl_bronce.sql` |
| Procedimiento de carga | `proc_cargar_<capa>.sql` | `proc_cargar_bronce.sql` |
| Pruebas | `revision_<capa>.sql` | `revision_bronce.sql` |
