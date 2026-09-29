# Flujo de desarrollo y pruebas con updates

Este proyecto usa un flujo incremental basado en scripts `update_00X.py` para aplicar cambios locales de forma controlada y probar inmediatamente el ejecutable de LaguNET bi.

La idea es sencilla:

```text
update_00X.py
    ↓
verificar proyecto
    ↓
backup
    ↓
aplicar cambios
    ↓
limpiar compilados
    ↓
recompilar
    ↓
probar LaguNETbi.exe
    ↓
git diff
    ↓
commit / push
```

## Estructura local esperada

Los scripts de actualización se guardan en el Escritorio, junto a la carpeta del repositorio:

```text
Desktop\
├─ update_00X.py
└─ LaguNETbi\
   ├─ LaguNETbi.lpi
   ├─ LaguNETbi.lpr
   ├─ unit1.pas
   ├─ unit1.lfm
   └─ ...
```

El updater debe localizar el proyecto desde su propia ubicación:

```python
script_dir = Path(__file__).resolve().parent
root = script_dir / "LaguNETbi"
```

Como compatibilidad adicional, puede aceptar que el updater se copie dentro del propio repositorio.

## Reglas de los updates

Cada `update_00X.py` debe:

1. Mostrar claramente la ruta del proyecto que va a modificar.
2. Verificar que los archivos esperados existen.
3. Comprobar, cuando corresponda, que el proyecto está en el estado esperado antes de modificarlo.
4. Crear una copia de seguridad de los archivos modificados.
5. Aplicar únicamente el cambio correspondiente a ese update.
6. Limpiar los compilados anteriores cuando haya cambios de código.
7. Recompilar el proyecto cuando sea posible.
8. Mostrar el resultado de compilación.
9. Mantener la consola abierta al terminar para poder leer toda la salida.

La consola debe permanecer abierta tanto si el update termina correctamente como si falla:

```python
try:
    input("\nPulsa Enter para cerrar...")
except EOFError:
    pass
```

No deben existir salidas anticipadas que eviten esta pausa final.

## Backups

Los archivos modificados se guardan antes del cambio en:

```text
LaguNETbi\.lagunetbi-backup\update_00X-AAAAMMDD-HHMMSS\
```

Si el estado del proyecto no coincide con el esperado, el updater debe abortar sin modificar ningún archivo.

## Limpieza de compilados

Después de modificar código Pascal o formularios Lazarus se elimina:

```text
LaguNETbi\lib\
```

Esto evita ejecutar unidades compiladas antiguas y obliga a Lazarus/FPC a reconstruir el proyecto.

Este paso se añadió después de detectar que un `.lfm` modificado correctamente podía no reflejarse al ejecutar un binario antiguo.

## Compilación automática

El updater intenta localizar `lazbuild.exe`, normalmente en:

```text
C:\lazarus\lazbuild.exe
```

y recompila con:

```text
lazbuild --build-all LaguNETbi.lpi
```

Si la compilación termina correctamente, se puede ejecutar directamente:

```text
LaguNETbi.exe
```

Si `lazbuild` no está disponible, el updater debe indicarlo y la compilación se realiza desde Lazarus:

```text
Ctrl+F9   Build
F9        Run
```

## LaguNETbi.exe debe estar cerrado antes de recompilar

Windows no permite reemplazar el ejecutable mientras está en uso.

Como LaguNET bi vive en el system tray, cerrar la ventana principal no significa necesariamente terminar el proceso.

Antes de recompilar:

1. cerrar LaguNET bi mediante `Salir` desde el menú del tray;
2. comprobar que `LaguNETbi.exe` ya no está ejecutándose;
3. ejecutar el updater.

El error típico cuando el ejecutable continúa abierto es:

```text
Can't create object file: LaguNETbi.exe (error code: 5)
```

El código 5 de Windows indica acceso denegado al intentar reemplazar el `.exe`.

Los futuros updaters pueden comprobar esta situación antes de iniciar la compilación y mostrar un mensaje claro.

## Prueba después de cada update

El desarrollo es incremental. Cada update debe introducir un cambio pequeño y observable.

Después de aplicar un update:

1. comprobar que aparece `COMPILACION OK`;
2. ejecutar `LaguNETbi.exe`;
3. probar únicamente la funcionalidad modificada;
4. confirmar que el comportamiento anterior continúa funcionando;
5. revisar los cambios con `git diff`;
6. hacer commit y push cuando la prueba sea satisfactoria.

No se deben agrupar muchas funcionalidades nuevas en un mismo update si pueden probarse por separado.

## Filosofía de desarrollo

La versión original de LaguNET es la especificación funcional.

Primero se busca paridad con el comportamiento existente. Las mejoras de UX, refactors y nuevas funcionalidades se hacen después.

El ciclo preferido es:

```text
una función
→ un update
→ una compilación
→ una prueba real
→ siguiente función
```

Este flujo permite detectar rápidamente si el problema está en el código fuente, Lazarus, la compilación, el ejecutable antiguo o el propio comportamiento de la aplicación.
