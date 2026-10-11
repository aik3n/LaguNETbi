# Política de ejecución privilegiada

## Principio

LaguNETbi es una aplicación Windows orientada a cambiar configuraciones de red y
puede ejecutarse con privilegios de administrador.

Tener privilegios elevados **no significa que deba ejecutar cualquier comando**.

La regla del proyecto es:

> LaguNETbi solo ejecuta las operaciones necesarias para su objetivo de
> configuración de red y las operaciones que estén soportadas explícitamente.

El BAT continúa siendo el formato portable y la fuente de configuración, pero
LaguNETbi **no debe convertirse en un ejecutor genérico de BAT elevado**.


## Fuente de verdad

El archivo `.bat` es la fuente de verdad de cada perfil.

LaguNETbi puede:

- leer el BAT;
- interpretar las operaciones que conoce;
- mostrar su contenido real;
- modificar las líneas que entiende cuando el usuario pulsa `Guardar`;
- conservar líneas adicionales que no entiende.

Las líneas desconocidas o personalizadas pueden permanecer en el archivo sin
que LaguNETbi tenga que ejecutarlas.


## Guardar

`Guardar` nunca ejecuta comandos.

Su función es únicamente modificar el archivo seleccionado y volver a leerlo
desde disco para actualizar la interfaz.


## Aplicar y ejecución desde el tray

Los puntos de ejecución de LaguNETbi deben usar una lista explícita de
operaciones soportadas.

No se debe ejecutar el BAT completo mediante mecanismos equivalentes a:

```text
cmd /c archivo.bat
ShellExecute(archivo.bat)
```

cuando LaguNETbi esté ejecutándose con privilegios elevados.

En su lugar, LaguNETbi analiza el BAT y ejecuta únicamente las operaciones que
reconoce y que forman parte de su función.


## Operaciones previstas

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


## Líneas adicionales

Un BAT puede contener 1, 10 o 50 líneas.

LaguNETbi debe conservar las líneas que no reconoce cuando modifica un perfil,
siempre que sea posible hacerlo sin destruir contenido del usuario.

Sin embargo:

> conservar una línea no implica autorizar su ejecución.

Una línea desconocida debe mostrarse en el visor del BAT, pero no debe recibir
automáticamente privilegios de administrador a través de LaguNETbi.


## Nuevos comandos

Si en el futuro LaguNETbi necesita soportar una operación adicional:

1. se define su utilidad concreta dentro del objetivo de LaguNETbi;
2. se añade explícitamente al parser;
3. se valida su entrada;
4. se añade explícitamente a la lógica de ejecución;
5. se documenta.

No habrá un mecanismo genérico del tipo "ejecutar cualquier línea que aparezca
en el BAT" como fallback.


## Validación

Antes de ejecutar una operación soportada, LaguNETbi debe validar los datos que
controla, por ejemplo:

- adaptador;
- dirección IPv4;
- máscara;
- gateway;
- SSID;
- destino de ping.

La aplicación no debe construir comandos elevados a partir de texto arbitrario
sin comprobar.


## Separación entre edición y ejecución

El flujo esperado es:

```text
Seleccionar BAT
      |
      v
Leer archivo real
      |
      +--> mostrar contenido real
      |
      +--> rellenar campos reconocidos

Editar campos
      |
      v
No ejecutar nada
No modificar el BAT hasta Guardar

Guardar
      |
      v
Modificar solo información soportada
      |
      v
Releer BAT real

Aplicar / tray
      |
      v
Interpretar BAT
      |
      v
Ejecutar solo operaciones permitidas
```

Esta separación debe mantenerse incluso si en el futuro la interfaz cambia.


## Regla práctica para desarrollo

Ante la duda sobre si LaguNETbi debería ejecutar una línea:

> si no es necesaria para la función de red que LaguNETbi soporta
> explícitamente, no se ejecuta.

Es preferible añadir soporte consciente para una nueva operación que ampliar
los privilegios de ejecución de forma genérica.
