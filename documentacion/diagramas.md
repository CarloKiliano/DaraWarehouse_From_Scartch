# 🗺️ Diagramas del proyecto

Los diagramas están escritos en **Mermaid**, así que GitHub los dibuja solos al abrir este archivo.
En Antigravity puedes verlos con una extensión de vista previa de Mermaid.

La idea es que también los dibujes tú en **Draw.io** (como en el video) y guardes los
`.drawio` en la carpeta `diagramas/`; dibujarlos es buena forma de entender el proyecto.

---

## 1. Arquitectura general

```mermaid
flowchart LR
    subgraph fuentes["Fuentes"]
        crm["CRM<br/>3 archivos CSV"]
        erp["ERP<br/>3 archivos CSV"]
    end

    subgraph almacen["Almacén de datos: almacen_datos (SQL Server)"]
        bronce["🥉 BRONCE<br/>datos crudos<br/>tablas · carga completa"]
        plata["🥈 PLATA<br/>datos limpios<br/>tablas · carga completa"]
        oro["🥇 ORO<br/>modelo estrella<br/>vistas"]
    end

    subgraph consumo["Consumo"]
        sql["Consultas SQL<br/>análisis"]
        bi["Reportes / BI"]
        ml["Minería de datos"]
    end

    crm --> bronce
    erp --> bronce
    bronce -- "bronce.cargar_bronce" --> plata
    plata -- "plata.cargar_plata" --> oro
    oro --> sql
    oro --> bi
    oro --> ml
```

---

## 2. Flujo de datos (linaje): de qué tabla sale cada cosa

```mermaid
flowchart LR
    subgraph B["Bronce"]
        b1[crm_cust_info]
        b2[crm_prd_info]
        b3[crm_sales_details]
        b4[erp_cust_az12]
        b5[erp_loc_a101]
        b6[erp_px_cat_g1v2]
    end
    subgraph P["Plata"]
        p1[crm_cust_info]
        p2[crm_prd_info]
        p3[crm_sales_details]
        p4[erp_cust_az12]
        p5[erp_loc_a101]
        p6[erp_px_cat_g1v2]
    end
    subgraph O["Oro"]
        o1[dim_clientes]
        o2[dim_productos]
        o3[fact_ventas]
    end
    b1 --> p1; b2 --> p2; b3 --> p3; b4 --> p4; b5 --> p5; b6 --> p6
    p1 --> o1; p4 --> o1; p5 --> o1
    p2 --> o2; p6 --> o2
    p3 --> o3
```

---

## 3. Cómo se relacionan las tablas de las dos fuentes

Esto es lo que hay que descubrir antes de limpiar: qué columna de un sistema "apunta" a cuál del otro.

```mermaid
flowchart TB
    cust["crm_cust_info<br/>cst_id · cst_key"]
    prd["crm_prd_info<br/>prd_key"]
    sales["crm_sales_details<br/>sls_prd_key · sls_cust_id"]
    az["erp_cust_az12<br/>cid"]
    loc["erp_loc_a101<br/>cid"]
    cat["erp_px_cat_g1v2<br/>id"]

    sales -- "sls_cust_id = cst_id" --> cust
    sales -- "sls_prd_key = parte final de prd_key" --> prd
    cust -- "cst_key = cid (sin 'NAS')" --> az
    cust -- "cst_key = cid (sin '-')" --> loc
    prd -- "primeros 5 de prd_key = id (con '_')" --> cat
```

---

## 4. Modelo estrella (capa oro)

```mermaid
erDiagram
    dim_clientes ||--o{ fact_ventas : "cliente_llave"
    dim_productos ||--o{ fact_ventas : "producto_llave"

    dim_clientes {
        int cliente_llave PK
        int cliente_id
        string numero_cliente
        string nombre
        string apellido
        string pais
        string estado_civil
        string genero
        date fecha_nacimiento
        date fecha_alta
    }
    dim_productos {
        int producto_llave PK
        int producto_id
        string numero_producto
        string nombre_producto
        string categoria_id
        string categoria
        string subcategoria
        string requiere_mantenimiento
        int costo
        string linea_producto
        date fecha_inicio
    }
    fact_ventas {
        string numero_orden
        int producto_llave FK
        int cliente_llave FK
        date fecha_pedido
        date fecha_envio
        date fecha_vencimiento
        int monto_venta
        int cantidad
        int precio
    }
```
