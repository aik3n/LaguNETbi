# Política de ejecución privilegiada

## Principio

LaguNETbi es una aplicación Windows orientada a cambiar configuraciones de red y
puede ejecutarse con privilegios de administrador.

Tener privilegios elevados **no significa que deba ejecutar cualquier comando**.

La regla del proyecto es:

> LaguNETbi solo ejecuta las operaciones necesarias para su objetivo de
> configuración de red y las operaciones que estén soportadas explícitamente.

LaguNETbi no debe convertirse en un ejecutor genérico de comandos elevados.


## Dos fuentes según la acción

Es importante distinguir entre la **configuración actual de la interfaz** y el
**archivo BAT guardado**.

### Ventana principal

En la ventana principal, los campos visibles son el estado de trabajo actual:

- adaptador;
- DHCP / estática;
- IP;
- máscara;
- gateway;
- Wi-Fi;
- SSID;
- test ping;
- descripción.

El botón `Aplicar` / `Establecer` usa **estos campos actuales**.

No vuelve a leer el BAT para decidir qué ejecutar.

Por tanto, es posible modificar un valor y aplicarlo sin guardar primero el BAT.


### Archivo BAT

El BAT es la representación persistente y portable del perfil.

Cuando se selecciona un BAT:

1. LaguNETbi lee el archivo real desde disco;
2. muestra su contenido real;
3. interpreta únicamente las partes que conoce;
4. rellena los campos de configuración con esos valores.

Después de esta carga, los campos son editables de forma independiente.


## Guardar

`Guardar` nunca ejecuta comandos.

Su función es:

1. tomar los valores actuales de los campos;
2. actualizar en el BAT las partes que LaguNETbi soporta;
3. conservar las líneas adicionales siempre que sea posible;
4. guardar el archivo;
5. volver a leer el BAT real para actualizar la interfaz y el visor.

Modificar campos sin pulsar `Guardar` no cambia el BAT.


## Aplicar / Establecer

`Aplicar` / `Establecer` no ejecuta el BAT seleccionado.

Construye y ejecuta únicamente las operaciones de red soportadas a partir de
los **valores actuales de la interfaz**.

Ejemplo conceptual:

```text
Campos actuales
      |
      +-- adaptador
      +-- DHCP / IP / máscara / gateway
      +-- Wi-Fi / SSID
      +-- test ping
      |
      v
Aplicar / Establecer
      |
      v
Validar valores
      |
      v
Ejecutar solo operaciones soportadas
```

El contenido de un BAT puede haber sido el origen de esos campos, pero no es lo
que se ejecuta directamente desde este botón.


## Ejecución desde el tray

El tray es diferente porque allí el usuario elige directamente un perfil BAT.

En ese flujo:

1. se lee el BAT seleccionado;
2. se interpretan sus operaciones soportadas;
3. se validan;
4. se ejecutan únicamente esas operaciones permitidas.

Nunca debe hacerse un equivalente genérico a:

```text
cmd /c archivo.bat
ShellExecute(archivo.bat)
```

con privilegios elevados.


## Operaciones soportadas actualmente

En el alcance actual del proyecto están previstas explícitamente:

```text
netsh interface ipv4 set address ...
netsh wlan connect ...
:: testPing=...
```

`:: testPing=` es metadata de LaguNETbi. Indica una comprobación posterior y no
es un comando de Windows que deba ejecutarse como una línea del BAT.

La descripción:

```text
:: description=...
```

también es metadata y nunca se ejecuta.


## Líneas adicionales del BAT

Un BAT puede contener 1, 10 o 50 líneas.

LaguNETbi debe conservar las líneas que no reconoce cuando modifica un perfil,
siempre que sea posible hacerlo sin destruir contenido del usuario.

Sin embargo:

> conservar una línea no implica autorizar su ejecución.

Una línea desconocida puede mostrarse en el visor y conservarse en el archivo,
pero no debe recibir automáticamente privilegios de administrador a través de
LaguNETbi.


## Nuevos comandos

Si en el futuro LaguNETbi necesita soportar una operación adicional:

1. se define su utilidad concreta dentro del objetivo de LaguNETbi;
2. se añade explícitamente al parser;
3. se valida su entrada;
4. se añade explícitamente a la lógica de ejecución;
5. se documenta.

No habrá un fallback del tipo "si aparece en el BAT, ejecútalo".


## Validación

Antes de ejecutar una operación, LaguNETbi debe validar los valores relevantes,
por ejemplo:

- adaptador;
- dirección IPv4;
- máscara;
- gateway;
- SSID;
- destino de ping.

La aplicación no debe construir comandos elevados a partir de texto arbitrario
sin comprobar.


## Flujo completo

```text
CLICK EN BAT
      |
      v
Leer BAT real
      |
      +--> mostrar BAT real
      |
      +--> rellenar campos
                |
                v
           editar campos
             /       \
            /         \
           v           v
       Guardar       Aplicar
          |             |
          v             v
   escribir BAT    usar campos actuales
          |             |
          v             v
    releer BAT     validar y ejecutar
```

El botón `Aplicar` no necesita que los cambios hayan sido guardados primero.


## Regla práctica para desarrollo

Hay dos preguntas diferentes:

**¿Qué guarda LaguNETbi?**

Los valores actuales de la interfaz, dentro de las partes del BAT que soporta.

**¿Qué ejecuta LaguNETbi?**

En la ventana principal, las operaciones de red derivadas de los campos
actuales. En el tray, las operaciones soportadas interpretadas desde el BAT
seleccionado.

En ambos casos, solo se ejecuta aquello que LaguNETbi soporta explícitamente.
