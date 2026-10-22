# Desarrollo y actualizaciones de LaguNETbi

## Criterio de trabajo

Minimo codigo propio y minimo trabajo de mantenimiento. Preferir Lazarus y Git
frente a mecanismos nuevos que dupliquen capacidades existentes.

## Updates (Windows PowerShell)

1. Cerrar LaguNETbi.
2. Comprobar el commit base indicado por cada update y revisar `git status`.
3. Ejecutar el `.ps1` junto a la carpeta `LaguNETbi`, o indicar `-ProjectPath`.
4. Si cambia Pascal, LFM o LPI: compilar con `lazbuild --build-all LaguNETbi.lpi`.
5. Probar las funciones afectadas, revisar `git diff` y crear un commit.

Ejemplo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\LaguNETbi_Update_0XX.ps1"
```

No es necesario Python. No duplicar las copias de seguridad que ya proporciona
Git: antes de un update, confirmar un estado funcional. Un script debe negarse
a sobrescribir cambios desconocidos y restaurar solo los archivos que modifique.

## Traducciones nativas de Lazarus

- El idioma original es ingles. Los textos permanentes se definen en Caption y Hint.
- Los textos dependientes del estado se declaran como `resourcestring` en Pascal.
- `LCLTranslator.SetDefaultLang` aplica los idiomas, tambien en caliente.
- Un archivo por idioma: `lang/LaguNETbi.es.po`, `.eu.po`, `.de.po`, etc.
- `lang/LaguNETbi.en.po` permite volver al ingles sin reiniciar.
- `lang/LaguNETbi.pot` es la plantilla; NO es un idioma descargable.
- `LaguNETbi.ini` (junto al EXE) solo guarda preferencias y configuracion.
- No se usan archivos INI para las traducciones.

### Regenerar la plantilla desde Lazarus

1. Abrir `LaguNETbi.lpi` en Lazarus.
2. Verificar: Proyecto > Opciones del proyecto > i18n:
   Enable i18n activado y directorio PO `lang`.
3. Si es necesario, usar Proyecto > Resave forms with i18n (o equivalente
   en la version instalada) para actualizar las propiedades de formularios.
4. En las opciones i18n activar `Force update PO files on next build`.
5. Compilar el proyecto desde el IDE y comprobar `lang/LaguNETbi.pot`.
6. Verificar que aparecen textos de `unit1`, `uSettingsForm`, `uQuickForm`
   y propiedades de los formularios. No basta con una sola entrada.
7. Revisar `git diff` antes de aceptar cambios en los catalogos `.po`.
   Las traducciones existentes no deben desaparecer.
8. Si falta algun resourcestring, verificar que su unidad esta incluida
   en el Inspector de Proyecto; no crear un segundo generador.

Para comprobar Update 039 despues de generar la plantilla:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\LaguNETbi_Update_039.ps1" -VerifyPot
```

### Pruebas de idioma

- Ingles, espanol, euskera, aleman y automatico sin reiniciar.
- Formularios, menu del tray, popup y mensajes dinamicos.
- Sin Internet y sin carpeta `lang`: funcionamiento con ingles integrado.
- Nunca traducir datos del usuario (BAT, IP, nombres de perfil o Wi-Fi).

## Alcance de Update 039

Eliminar los cuatro INI de traducciones antiguas y sustituir la documentacion
obsoleta. No tocar el motor de red, scripts BAT, recursos de formularios ni
los catalogos `.po`. La regeneracion del `.pot` se realiza con Lazarus.
