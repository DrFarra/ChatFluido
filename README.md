# ChatFluido

Versión propia, escrita desde [SPEC.md](SPEC.md), de lo que hace Watusi con las burbujas de chat:
marcas de mensajes eliminados/editados, burbujas con transparencia y barra de info al arrastrar.

Tiene dos modos para comparar en el mismo iPhone:

- **Watusi**: lo hace igual que Watusi (todo en cada `layoutSubviews`, listas recorridas una a una,
  ajustes leídos cada vez, barra buscada por número).
- **Arreglado**: mismo resultado, con conjuntos, ajustes en memoria y estilo aplicado solo si cambia.

El chat tiene 3000 mensajes y 20 000 eliminados guardados de otros chats, como la lista que Watusi
acumula. Abajo se ve `Hz · peor imagen en ms · imágenes tarde`.

## Instalar

1. GitHub → pestaña **Actions** → última ejecución de "Build unsigned IPA" → descarga
   `ChatFluido-unsigned-ipa`.
2. Descomprime y firma/instala `ChatFluido-unsigned.ipa` igual que ClipDeck.

## Pruebas

Se ejecutan solas en cada push (GitHub Actions, simulador de iPhone). En un Mac:
`brew install xcodegen && xcodegen && xcodebuild test -scheme ChatFluido -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Límites

- Es una demo: no se conecta a WhatsApp ni lee tus datos.
- La marca no abre el mensaje original al tocarla.
- Los números miden esta demo, no WhatsApp.
