@echo off
cd /d "%~dp0"
echo Subiendo SELECCIOM a GitHub...
git add -A -- . ":!subir_github.bat"
git commit -m "Respaldo: cargar respaldo JSON para recuperar informacion"
git push
echo.
echo Listo. Puedes cerrar esta ventana.
pause
