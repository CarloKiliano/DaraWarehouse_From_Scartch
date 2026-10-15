/*
===============================================================================
 proc_cargar_bronce.sql
 Procedimiento almacenado que carga los CSV en la capa BRONCE
===============================================================================
 ¿Qué hace este script?
   Crea (o actualiza) el procedimiento 'bronce.cargar_bronce'. Este script
   NO carga los datos por sí solo: solo "guarda la receta". Para cargar hay
   que EJECUTAR el procedimiento (ver al final).

 ¿Qué hace el procedimiento cuando lo ejecutamos?
   Para cada uno de los 6 archivos:
     1. TRUNCATE  → vacía la tabla (borra todas sus filas, pero no la tabla).
     2. BULK INSERT → copia todo el CSV a la tabla de un jalón.
     3. Cuenta las filas cargadas e imprime cuánto tardó.
   A esto se le llama CARGA COMPLETA ("truncate & insert"): cada vez se
   reemplaza todo, así nunca quedan filas repetidas de cargas anteriores.

 Nota para mí:
   - Un PROCEDIMIENTO ALMACENADO es como una función guardada dentro de la
     base de datos. Lo escribimos una vez y lo corremos cuantas veces
     queramos con EXEC.
   - TRY...CATCH: si algo falla dentro del TRY, saltamos al CATCH y ahí
     mostramos qué pasó, en vez de que el error quede perdido.
   - BULK INSERT no acepta variables en la ruta del archivo, por eso armamos
     la instrucción como texto (@sql) y la ejecutamos con sp_executesql.
     A eso se le llama "SQL dinámico".

 Parámetro:
   @ruta_datasets = carpeta donde están source_crm y source_erp.
   Si mueves el proyecto de lugar, solo cambias este valor.

 Uso:
   EXEC bronce.cargar_bronce;
   -- o con otra ruta:
   EXEC bronce.cargar_bronce @ruta_datasets = N'C:\datos_sql\datasets';
===============================================================================
*/

USE almacen_datos;
GO

CREATE OR ALTER PROCEDURE bronce.cargar_bronce
    @ruta_datasets NVARCHAR(400) = N'C:\Users\PC\Desktop\Ciencia De Datos\DataWarehouse\datasets'
AS
BEGIN
    SET NOCOUNT ON;   -- evita los mensajes automáticos "(n rows affected)"

    -- Variables para medir tiempos y armar las instrucciones
    DECLARE @inicio_total   DATETIME2 = SYSDATETIME();
    DECLARE @inicio         DATETIME2;
    DECLARE @sql            NVARCHAR(MAX);
    DECLARE @filas          INT;
    DECLARE @i              INT = 1;
    DECLARE @total_cargas   INT;
    DECLARE @sistema        NVARCHAR(10);
    DECLARE @sistema_previo NVARCHAR(10) = N'';
    DECLARE @tabla          NVARCHAR(128);
    DECLARE @archivo        NVARCHAR(200);

    -- Lista de cargas: qué archivo va a qué tabla.
    -- Si algún día se agrega un archivo nuevo, solo se añade una fila aquí.
    DECLARE @cargas TABLE (
        orden   INT,
        sistema NVARCHAR(10),
        tabla   NVARCHAR(128),
        archivo NVARCHAR(200)
    );

    INSERT INTO @cargas (orden, sistema, tabla, archivo)
    VALUES
        (1, N'CRM', N'bronce.crm_cust_info',     N'source_crm\cust_info.csv'),
        (2, N'CRM', N'bronce.crm_prd_info',      N'source_crm\prd_info.csv'),
        (3, N'CRM', N'bronce.crm_sales_details', N'source_crm\sales_details.csv'),
        (4, N'ERP', N'bronce.erp_cust_az12',     N'source_erp\CUST_AZ12.csv'),
        (5, N'ERP', N'bronce.erp_loc_a101',      N'source_erp\LOC_A101.csv'),
        (6, N'ERP', N'bronce.erp_px_cat_g1v2',   N'source_erp\PX_CAT_G1V2.csv');

    SELECT @total_cargas = COUNT(*) FROM @cargas;

    BEGIN TRY
        PRINT '================================================';
        PRINT ' Cargando la capa BRONCE';
        PRINT ' Carpeta de datos: ' + @ruta_datasets;
        PRINT '================================================';

        -- Recorremos la lista de cargas una por una
        WHILE @i <= @total_cargas
        BEGIN
            -- Tomamos la fila número @i de la lista
            SELECT @sistema = sistema, @tabla = tabla, @archivo = archivo
            FROM @cargas
            WHERE orden = @i;

            -- Encabezado cada vez que cambiamos de sistema (CRM → ERP)
            IF @sistema <> @sistema_previo
            BEGIN
                PRINT '';
                PRINT '------------------------------------------------';
                PRINT ' Tablas del ' + @sistema;
                PRINT '------------------------------------------------';
                SET @sistema_previo = @sistema;
            END;

            SET @inicio = SYSDATETIME();

            -- Armamos el texto de la instrucción. Quedaría algo así:
            --   TRUNCATE TABLE bronce.crm_cust_info;
            --   BULK INSERT bronce.crm_cust_info
            --   FROM 'C:\...\datasets\source_crm\cust_info.csv'
            --   WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ...);
            --
            -- Opciones de BULK INSERT:
            --   FIRSTROW = 2         → saltamos la fila 1 (los encabezados)
            --   FIELDTERMINATOR = ','→ las columnas se separan con coma
            --   CODEPAGE = '65001'   → el archivo está en UTF-8
            --   TABLOCK              → bloquea la tabla mientras carga (más rápido)
            SET @sql =
                  N'TRUNCATE TABLE ' + @tabla + N'; '
                + N'BULK INSERT ' + @tabla
                + N' FROM ''' + REPLACE(@ruta_datasets + N'\' + @archivo, N'''', N'''''') + N''''
                + N' WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', CODEPAGE = ''65001'', TABLOCK);';

            PRINT '>> Cargando ' + @tabla + '  <--  ' + @archivo;
            EXEC sp_executesql @sql;

            -- Contamos cuántas filas quedaron en la tabla
            SET @sql = N'SELECT @n = COUNT(*) FROM ' + @tabla + N';';
            EXEC sp_executesql @sql, N'@n INT OUTPUT', @n = @filas OUTPUT;

            PRINT CONCAT('   ', @filas, ' filas cargadas en ',
                         DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()), ' ms');

            SET @i += 1;
        END;

        PRINT '';
        PRINT '================================================';
        PRINT CONCAT(' Capa BRONCE cargada. Tiempo total: ',
                     DATEDIFF(MILLISECOND, @inicio_total, SYSDATETIME()), ' ms');
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '';
        PRINT '================================================';
        PRINT ' ERROR al cargar la capa BRONCE';
        PRINT ' Tabla que estaba cargando: ' + ISNULL(@tabla, '(ninguna)');
        PRINT ' Mensaje: ' + ERROR_MESSAGE();
        PRINT ' Numero de error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        PRINT '================================================';
        THROW;   -- vuelve a lanzar el error para que el editor lo marque en rojo
    END CATCH;
END;
GO

-- Para cargar los datos, ejecuta esta línea (sola o seleccionándola):
-- EXEC bronce.cargar_bronce;
