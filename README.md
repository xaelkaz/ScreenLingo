# GameLingo

GameLingo es una aplicación nativa para macOS que traduce al español el texto en inglés visible en un juego.

## Flujo de uso

1. Abre `GameLingo.app`. Aparecerá un icono de traducción en la barra de menús.
2. Presiona `⌥⌘T` desde cualquier aplicación. Puedes cambiar este atajo en **Ajustes**.
3. Arrastra para seleccionar el diálogo en inglés.
4. GameLingo mostrará la traducción en una tarjeta flotante.
5. Usa **Copiar** para llevar la traducción al portapapeles o `Esc` para cerrar.

La captura, el reconocimiento de texto y la traducción se procesan localmente con ScreenCaptureKit, Vision y Translation de Apple.

## Atajos y modos

- **Traducir una región:** `⌥⌘T` de forma predeterminada. Es completamente configurable.
- **Repetir última región:** `⌥⌘R`. Conserva la zona incluso después de reiniciar GameLingo.
- **Subtítulos automáticos:** `⌥⌘S`. Selecciona una zona una vez y GameLingo detecta los cambios de diálogo.

También puedes iniciar o detener todos estos modos desde el icono de GameLingo en la barra de menús.

### Subtítulos automáticos (experimental)

1. Presiona `⌥⌘S` y selecciona la caja de diálogo del juego.
2. GameLingo revisará esa zona periódicamente y solo traducirá cuando detecte un cambio.
3. Presiona `⌥⌘S` nuevamente para detener el modo.

La captura continua excluye las ventanas de GameLingo para que el overlay no vuelva a ser leído por el OCR. La región debe estar completamente dentro de un solo monitor.

Desde **Ajustes** puedes cambiar la frecuencia de revisión entre 0.5 y 2 segundos, ocultar el texto original y grabar un atajo nuevo.

## Requisitos

- macOS 15.2 o posterior.
- Swift 6 / Xcode Command Line Tools. Xcode completo no es necesario para compilar el MVP.
- Permiso de **Grabación de pantalla** para GameLingo.
- La primera traducción puede pedir permiso para descargar el modelo inglés–español.

## Compilar la aplicación

```bash
chmod +x Scripts/build-app.sh Scripts/test.sh
./Scripts/test.sh
./Scripts/build-app.sh
open dist/GameLingo.app
```

El script genera `dist/GameLingo.app` y aplica una firma local ad hoc. Para distribuir la aplicación a otros Macs será necesario firmarla con Apple Developer ID y notarizarla.

## Permisos

En el primer uso, macOS pedirá acceso para capturar la pantalla. Si no aparece o se rechazó:

1. Abre **Ajustes del Sistema**.
2. Entra en **Privacidad y seguridad → Grabación de pantalla**.
3. Activa GameLingo.
4. Cierra y vuelve a abrir la aplicación si macOS lo solicita.

## Alcance del MVP

- Traducción fija de inglés a español.
- Selección rectangular en uno o varios monitores.
- OCR optimizado para precisión.
- Ventana flotante sobre espacios y aplicaciones a pantalla completa.
- Atajo principal configurable y persistente.
- Repetición persistente de la última región.
- Modo experimental de subtítulos automáticos con detección de cambios.

Algunos juegos con captura exclusiva de pantalla o protecciones especiales pueden impedir que macOS entregue la imagen. En esos casos, usar el modo **ventana sin bordes** suele ser la opción más compatible.
