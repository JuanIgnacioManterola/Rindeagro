# Sincronizar con mi compañero

Ejecutá estos pasos en orden:

1. Asegurate de estar en `main`: corré `git checkout main`
2. Bajá los últimos cambios: `git pull origin main`
3. Mostrá un resumen de qué archivos cambiaron y qué modificó (usá `git log --oneline -5` y `git diff HEAD~1 --stat`)
4. Abrí GitHub Pages en el navegador: `open https://juanignaciomanterola.github.io/Rindeagro/`
5. Contame en español qué cambió, de forma simple y clara.

## Flujo de trabajo con ramas (obligatorio desde ahora)

Antes de empezar cualquier feature o fix nuevo:
- Crear una rama: `git checkout -b feat/nombre-corto` o `git checkout -b fix/nombre-corto`
- Hacer los cambios y commits en esa rama
- Al terminar: `git push origin nombre-rama`
- Crear un PR en GitHub hacia `main`
- Hacer merge del PR

Nunca commitear directo a `main`.
