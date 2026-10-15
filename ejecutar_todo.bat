@echo off
REM ===========================================================================
REM  ejecutar_todo.bat
REM  Construye el almacen de datos completo, de cero, en orden:
REM    base de datos -> bronce -> plata -> oro -> pruebas
REM
REM  Como usarlo: doble clic, o desde la terminal en esta carpeta:
REM      .\ejecutar_todo.bat
REM
REM  Si tu servidor no es "localhost" (ej. localhost\SQLEXPRESS),
REM  cambia la linea "set SERVIDOR=..." de abajo.
REM
REM  OJO: borra y vuelve a crear la base almacen_datos.
REM  Antes de correrlo, en Antigravity/SSMS no tengas abierta la base "model".
REM ===========================================================================

chcp 65001 > nul
cd /d "%~dp0"

set "SERVIDOR=localhost"
set "SQL=sqlcmd -S %SERVIDOR% -E -C -b"

echo.
echo [1/9] Creando base de datos y esquemas...
%SQL% -i scripts\init_database.sql || goto :error

echo.
echo [2/9] Creando tablas de bronce...
%SQL% -i scripts\bronce\ddl_bronce.sql || goto :error

echo.
echo [3/9] Creando procedimiento de carga de bronce...
%SQL% -i scripts\bronce\proc_cargar_bronce.sql || goto :error

echo.
echo [4/9] Creando tablas de plata...
%SQL% -i scripts\plata\ddl_plata.sql || goto :error

echo.
echo [5/9] Creando procedimiento de carga de plata...
%SQL% -i scripts\plata\proc_cargar_plata.sql || goto :error

echo.
echo [6/9] Creando vistas de oro...
%SQL% -i scripts\oro\ddl_oro.sql || goto :error

echo.
echo [7/9] Cargando bronce (CSV -^> bronce)...
%SQL% -d almacen_datos -Q "EXEC bronce.cargar_bronce @ruta_datasets = N'%~dp0datasets';" || goto :error

echo.
echo [8/9] Cargando plata (bronce -^> plata)...
%SQL% -d almacen_datos -Q "EXEC plata.cargar_plata;" || goto :error

echo.
echo [9/9] Pruebas de calidad (busca que todo diga OK)...
%SQL% -d almacen_datos -W -s "|" -i pruebas\revision_bronce.sql || goto :error
%SQL% -d almacen_datos -W -s "|" -i pruebas\revision_plata.sql || goto :error
%SQL% -d almacen_datos -W -s "|" -i pruebas\revision_oro.sql || goto :error

echo.
echo ===========================================================
echo  LISTO: el almacen de datos se construyo sin errores.
echo ===========================================================
pause
exit /b 0

:error
echo.
echo ===========================================================
echo  ERROR: el proceso se detuvo. Lee el mensaje de arriba.
echo ===========================================================
pause
exit /b 1
