# GameLingo

GameLingo es una aplicación nativa para macOS que traduce al español el texto en inglés visible en un juego.

## Flujo de uso

1. Abre `GameLingo.app`. Aparecerá un icono de traducción en la barra de menús.
2. Presiona `⌥⌘T` desde cualquier aplicación.
3. Arrastra para seleccionar el diálogo en inglés.
4. GameLingo mostrará la traducción en una tarjeta flotante.
5. Usa **Copiar** para llevar la traducción al portapapeles o `Esc` para cerrar.

La captura, el reconocimiento de texto y la traducción se procesan localmente con ScreenCaptureKit, Vision y Translation de Apple.

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
- Atajo global fijo `⌥⌘T`.

Algunos juegos con captura exclusiva de pantalla o protecciones especiales pueden impedir que macOS entregue la imagen. En esos casos, usar el modo **ventana sin bordes** suele ser la opción más compatible.
