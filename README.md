# 🏗️ Almacén de Datos (Data Warehouse) con SQL Server

Proyecto de la materia **Minería de Datos para Ciencia de Datos** (Lic. en Ciencia de Datos, IIMAS – UNAM).

Es una réplica, adaptada al español y con comentarios de estudiante, del proyecto
[sql-data-warehouse-project](https://github.com/DataWithBaraa/sql-data-warehouse-project)
de **Baraa Khatib Salkini (Data With Baraa)**, publicado con licencia MIT.

---

## 🎯 ¿Qué estamos construyendo?

Una empresa tiene sus datos de ventas repartidos en **dos sistemas**:

| Sistema | Qué guarda | Archivos |
|---|---|---|
| **CRM** (gestión de clientes) | clientes, productos y ventas | `cust_info.csv`, `prd_info.csv`, `sales_details.csv` |
| **ERP** (planeación de recursos) | datos extra de clientes, ubicación y categorías de producto | `CUST_AZ12.csv`, `LOC_A101.csv`, `PX_CAT_G1V2.csv` |

Los datos vienen **sucios** (espacios de más, duplicados, códigos raros, fechas mal guardadas).
La meta es juntarlos en un solo lugar, limpiarlos y dejarlos listos para hacer análisis.

---

## 🥉🥈🥇 Arquitectura: Medallón (Bronce → Plata → Oro)

```
 Archivos CSV  ──►  BRONCE  ──►  PLATA  ──►  ORO  ──►  Análisis / reportes
 (CRM y ERP)       datos tal     datos       modelo
                   cual llegan   limpios     estrella
```

| Capa | Esquema | ¿Qué hace? | Tipo de objeto | Cómo se carga |
|---|---|---|---|---|
| **Bronce** | `bronce` | Copia exacta de los CSV, sin tocar nada. Sirve para rastrear errores hasta su origen. | Tablas | Carga completa (vaciar e insertar) |
| **Plata** | `plata` | Limpieza, estandarización y normalización. | Tablas | Carga completa |
| **Oro** | `oro` | Datos listos para el negocio: dimensiones y hechos (esquema estrella). | Vistas | No se carga, se calcula al consultar |

---

## 📂 Estructura del proyecto

```
DataWarehouse/
│
├── datasets/                         # Datos crudos tal como los entrega cada sistema
│   ├── source_crm/                   # 3 CSV del CRM
│   └── source_erp/                   # 3 CSV del ERP
│
├── documentacion/
│   ├── requisitos.md                 # Qué nos pidieron construir
│   ├── convenciones_nombres.md       # Reglas para nombrar todo (snake_case, español)
│   ├── catalogo_datos.md             # Qué significa cada columna de la capa oro
│   ├── diagramas.md                  # Arquitectura, flujo, relaciones y modelo estrella
│   └── diagramas/                    # Aquí van tus diagramas de Draw.io
│
├── scripts/
│   ├── init_database.sql             # Crea la base de datos y los esquemas
│   ├── bronce/
│   │   ├── ddl_bronce.sql            # Tablas de bronce
│   │   └── proc_cargar_bronce.sql    # CSV -> bronce
│   ├── plata/
│   │   ├── ddl_plata.sql             # Tablas de plata
│   │   └── proc_cargar_plata.sql     # bronce -> plata (aquí está toda la limpieza)
│   ├── oro/
│   │   └── ddl_oro.sql               # Vistas del modelo estrella
│   └── analisis/
│       └── analisis_exploratorio.sql # Preguntas de negocio sobre la capa oro
│
├── pruebas/
│   ├── revision_bronce.sql           # ¿Se cargaron todas las filas?
│   ├── revision_plata.sql            # ¿Quedaron limpios los datos?
│   └── revision_oro.sql              # ¿El modelo estrella está bien armado?
│
├── ejecutar_todo.bat                 # Construye todo de cero con un solo comando
├── .gitignore
└── README.md
```

> Las carpetas `datasets/source_crm` y `source_erp` conservan sus nombres originales a propósito:
> representan a los sistemas fuente, y la capa bronce respeta todo lo que viene de la fuente.

---

## ▶️ Cómo ejecutarlo

### Opción A: todo de un jalón

Desde la terminal, en la carpeta del proyecto:

```
.\ejecutar_todo.bat
```

Crea la base de datos, las 3 capas, carga los datos y corre las pruebas.
Al final, en las pruebas, todas las filas deben decir `OK`.

### Opción B: paso por paso (para ir entendiendo)

| # | Qué correr | Qué hace |
|---|---|---|
| 1 | `scripts/init_database.sql` | Crea `almacen_datos` y los esquemas (¡borra la base si ya existe!) |
| 2 | `scripts/bronce/ddl_bronce.sql` | Crea las tablas de bronce |
| 3 | `scripts/bronce/proc_cargar_bronce.sql` | Guarda el procedimiento de carga de bronce |
| 4 | `EXEC bronce.cargar_bronce;` | Carga los CSV |
| 5 | `pruebas/revision_bronce.sql` | Revisa bronce |
| 6 | `scripts/plata/ddl_plata.sql` | Crea las tablas de plata |
| 7 | `scripts/plata/proc_cargar_plata.sql` | Guarda el procedimiento de limpieza |
| 8 | `EXEC plata.cargar_plata;` | Limpia bronce y llena plata |
| 9 | `pruebas/revision_plata.sql` | Revisa plata |
| 10 | `scripts/oro/ddl_oro.sql` | Crea las vistas del modelo estrella |
| 11 | `pruebas/revision_oro.sql` | Revisa oro |
| 12 | `scripts/analisis/analisis_exploratorio.sql` | ¡A analizar! |

Desde la terminal, cada archivo se corre así (el `-b` hace que se **detenga en el primer error**):

```
sqlcmd -S localhost -E -C -b -i scripts\init_database.sql
sqlcmd -S localhost -E -C -b -d almacen_datos -Q "EXEC bronce.cargar_bronce;"
```

> Para volver a cargar datos nuevos no hace falta recrear nada: basta con
> `EXEC bronce.cargar_bronce;` y luego `EXEC plata.cargar_plata;`. Oro son vistas y se actualiza solo.

---

## 🧹 Problemas de calidad que encontramos (y cómo los resolvimos)

| Tabla | Problema | Solución en plata |
|---|---|---|
| 3 archivos CSV | La última línea no terminaba en salto de línea y `BULK INSERT` la ignoraba | Se agregó el salto de línea final al archivo |
| `crm_cust_info` | 4 filas basura sin id | Se descartan |
| `crm_cust_info` | Clientes repetidos (versiones del mismo registro) | Se queda la más reciente (`ROW_NUMBER`) |
| `crm_cust_info` | Espacios de más en nombres | `TRIM` |
| `crm_cust_info` | Estado civil y género como códigos | `Casado` / `Soltero`, `Masculino` / `Femenino`, `n/d` |
| `crm_prd_info` | La clave mezcla categoría y producto | Se separa en `cat_id` y `prd_key` |
| `crm_prd_info` | Costos vacíos | Se ponen en 0 |
| `crm_prd_info` | Fechas de fin anteriores a la de inicio | Se recalculan con `LEAD` |
| `crm_sales_details` | Fechas guardadas como número, algunas inválidas | Se convierten a `DATE`; las inválidas quedan en NULL |
| `crm_sales_details` | Montos y precios vacíos, negativos o que no cuadran | Se recalculan con `ventas = cantidad × precio` |
| `erp_cust_az12` | Ids con prefijo `NAS` | Se quita el prefijo |
| `erp_cust_az12` | Fechas de nacimiento en el futuro | Se ponen en NULL |
| `erp_cust_az12` | Género escrito de muchas formas | Se estandariza |
| `erp_loc_a101` | Ids con guion | Se quita el guion |
| `erp_loc_a101` | Países con varios nombres (`US`, `USA`, `DE`...) | Se estandarizan en español |

---

## ✅ Avance

- [x] Estructura del proyecto
- [x] Base de datos y esquemas
- [x] Capa bronce
- [x] Capa plata
- [x] Capa oro
- [x] Pruebas de calidad
- [x] Documentación (catálogo de datos y diagramas)
- [ ] Dibujar los diagramas en Draw.io
- [ ] Análisis exploratorio más a fondo

---

## 🛠️ Herramientas

- SQL Server 2025 (local)
- Antigravity como editor
- Git / GitHub
- Draw.io para diagramas

## 🙌 Créditos

Proyecto original: [DataWithBaraa/sql-data-warehouse-project](https://github.com/DataWithBaraa/sql-data-warehouse-project) (licencia MIT).
