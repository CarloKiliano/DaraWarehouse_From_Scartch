/*
===============================================================================
 init_database.sql
 Crea la base de datos y los esquemas del proyecto
===============================================================================
 ¿Qué hace este script?
   1. Revisa si ya existe una base llamada 'almacen_datos'. Si existe, la BORRA
      y la vuelve a crear desde cero.
   2. Crea los tres esquemas (las "carpetas" dentro de la base) que usaremos:
      bronce, plata y oro.

 ⚠️ CUIDADO:
   Correr este script borra TODO lo que haya en 'almacen_datos'. Úsalo solo
   cuando quieras empezar de cero.

 Nota para mí:
   Un ESQUEMA es como una carpeta dentro de la base de datos. Nos ayuda a
   separar las tablas de cada capa: bronce.crm_cust_info no se confunde con
   plata.crm_cust_info aunque se llamen igual.
===============================================================================
*/

-- Nos paramos en 'master' (la base del sistema) porque no podemos borrar
-- una base de datos mientras estamos "dentro" de ella.
USE master;
GO

-- Si la base ya existe, la borramos.
-- SINGLE_USER + ROLLBACK IMMEDIATE = "saca a todos los que estén conectados
-- y cancela lo que estén haciendo", para que nadie bloquee el borrado.
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'almacen_datos')
BEGIN
    ALTER DATABASE almacen_datos SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE almacen_datos;
END;
GO

-- SQL Server crea cada base nueva COPIANDO la base plantilla 'model'.
-- Para copiarla necesita que nadie la esté usando. Algunos editores (como la
-- extensión de Antigravity) abren conexiones a 'model' solo por mostrarla
-- en el panel, y eso bloquea el CREATE DATABASE.
-- Este bloque cierra cualquier conexión que esté usando 'model'
-- (sin tocar la nuestra: session_id <> @@SPID).
DECLARE @cerrar_conexiones NVARCHAR(MAX) = N'';

SELECT @cerrar_conexiones += N'KILL ' + CAST(session_id AS NVARCHAR(10)) + N'; '
FROM (
    SELECT session_id
    FROM sys.dm_exec_sessions
    WHERE database_id = DB_ID('model')
    UNION
    SELECT request_session_id
    FROM sys.dm_tran_locks
    WHERE resource_database_id = DB_ID('model')
) AS conexiones_en_model
WHERE session_id <> @@SPID;

IF @cerrar_conexiones <> N''
BEGIN
    PRINT 'Cerrando conexiones que usaban model: ' + @cerrar_conexiones;
    EXEC (@cerrar_conexiones);
END;
GO

-- Creamos la base de datos nueva
CREATE DATABASE almacen_datos;
GO

-- A partir de aquí todo se crea dentro de 'almacen_datos'
USE almacen_datos;
GO

-- Creamos un esquema por capa.
-- (CREATE SCHEMA debe ir solo en su bloque, por eso cada uno lleva su GO)
CREATE SCHEMA bronce;   -- datos crudos, tal cual llegan de los CSV
GO

CREATE SCHEMA plata;    -- datos limpios y estandarizados
GO

CREATE SCHEMA oro;      -- modelo final para análisis (esquema estrella)
GO

-- Comprobación rápida: deberían aparecer bronce, plata y oro
SELECT name AS esquema
FROM sys.schemas
WHERE name IN ('bronce', 'plata', 'oro');
GO
