# SPEC — Burbujas de chat con mensajes eliminados/editados y transparencia

Especificación del comportamiento observado en Watusi 1.3.26 (dentro de WhatsApp 26.38.74) y de
cómo afecta a la fluidez. Escrita a partir de evidencia de REA; no contiene código copiado.

Binario analizado: `Watusi.dylib`, SHA-256 `652efe738a37a3ba33670e39d2f16c1a4ef60b65228f37b995f79d8aea8e38de`
(cargado por `WhatsApp` en el load command #144, evidencia `ev_d7b6fd81…`).

## 1. Qué hace la función

Sobre cada burbuja de mensaje de un chat:

1. **Marca de eliminado / editado.** Si el usuario activa "conservar mensajes eliminados" o
   "conservar historial de ediciones", la burbuja de un mensaje que alguien borró o editó muestra un
   botón redondo. Al tocarlo se enseña el original.
2. **Transparencia y color de burbujas.** Si el tema activo define un color o una opacidad para las
   burbujas enviadas y/o recibidas, la burbuja se pinta con ese color y esa opacidad.
3. **"Info" en la barra del chat.** Si está activado, al empezar a arrastrar el chat se oculta con
   una animación de 0,3 s y reaparece 0,7 s después de soltar.

## 2. Entradas

| Entrada | Tipo | Origen observado |
|---|---|---|
| ID del mensaje (stanza ID) | texto, puede faltar | `message.stanzaID` (`ev_797d05d6`) |
| ¿Es mío? | sí/no | `message.isFromMe` (`ev_abcd22a4`) |
| Ajuste `wDisableMessagesRevoking` | sí/no | `0x21dbf8` (`ev_1241a217`) |
| Ajuste `wKeepEditedMessagesHistory` | sí/no | `0x21dc18` (`ev_19858a13`) |
| Ajuste `wChatBarStatus` | sí/no | `0x22c558` (`ev_a1d5313c`) |
| IDs de mensajes eliminados | colección | base `RevokedMessages.sqlite`, entidad `WSRevokedMessage` (`ev_79bc1e98`, `ev_86b032cf`) |
| IDs de mensajes editados | colección | la misma base (`ev_79bc1e98`) |
| Tema: color enviado / recibido | color o nada | `WSThemeManager.activeTheme` (`ev_edff768b`) |
| Tema: opacidad enviado / recibido activada | sí/no | idem |
| Tema: opacidad enviado / recibido | número 0–100 | idem |

## 3. Salidas

| Salida | Regla observada |
|---|---|
| Marca | **eliminado** si el ID está entre los eliminados; si no, **editado** si está entre los editados; si no, ninguna. Si el mensaje está eliminado y además editado, gana **eliminado** (la etiqueta accesible elige "MessageDeletedButton" antes que "MessageEditedButton", `ev_797d05d6`). |
| Sin marca | si los dos ajustes están desactivados, no se mira nada más (salida temprana, `ev_797d05d6`). |
| Opacidad de la burbuja | `opacidad / 100` si la opacidad de ese lado está activada; si no, `1,0` (`ev_edff768b`, `ev_abcd22a4`). |
| Color de la burbuja | el color del tema para ese lado (recibido si no es mío, enviado si es mío); si el tema no define color, se deja el de WhatsApp. |
| Sin tema | si el tema no define colores ni opacidades, no se toca la burbuja (`ev_edff768b`). |
| Barra de info | ocultar en 0,3 s al empezar a arrastrar; mostrar 0,7 s después de soltar (`ev_75b4b8a3`, `ev_fe434408`). |

## 4. Casos límite

- ID vacío o ausente → nunca está eliminado (`ev_36d3dfbf`) ni editado.
- Un borrado nuevo se añade a la colección y la marca aparece a partir de ese momento (`ev_d4034be0`).
- No hay forma de limpiar la colección: no se encontró ningún método de borrado (`ev_f2a21dcb`, búsqueda por nombre).
- Opacidad 0 → burbuja invisible pero presente; opacidad 100 → igual que sin opacidad.
- Celdas reutilizadas: una celda que mostraba una marca y pasa a un mensaje sin marca debe quitarla.

## 5. Por qué va a tirones en Watusi (observado + inferido)

Observado (todo ocurre en el hilo principal, el mismo que mueve el scroll):

- El trabajo se hace en `layoutSubviews`, que iOS llama **muchas veces** por celda, no una vez por mensaje
  (`0x16d8fc`, `0x187b78`, `0x18816c`, `0x189f38`).
- En cada llamada se leen los ajustes de `NSUserDefaults`, sin caché (`ev_dd8ab32a`).
- Las colecciones de IDs son **listas** (`NSMutableArray`) y se recorren elemento a elemento, dos veces
  por burbuja (`ev_ac18a773`, `ev_36d3dfbf`, `ev_86b032cf`).
- Las listas solo crecen (`ev_d4034be0`, `ev_f2a21dcb`).
- Cada borrado nuevo guarda la base de datos en el hilo principal (`ev_d4034be0`).
- El color, el degradado y la opacidad se vuelven a asignar en cada `layoutSubviews`, aunque no cambien (`ev_edff768b`).
- Al empezar y acabar cada arrastre se busca una vista por número recorriendo toda la pantalla (`viewWithTag:`, `ev_75b4b8a3`).

Inferido (no medido en el teléfono): con muchas marcas guardadas y burbujas transparentes, algunas imágenes no
llegan a tiempo (8,3 ms a 120 Hz) y el gesto de scroll tarda en responder.

## 6. Requisitos de la versión propia (decisiones de diseño, no observadas)

- Mismo comportamiento de la sección 3.
- Colecciones de IDs como **conjuntos** (búsqueda en tiempo constante).
- Ajustes leídos una vez y refrescados solo cuando cambian.
- La marca y el estilo se calculan al **configurar** la celda, no en cada `layoutSubviews`, y el estilo solo se aplica si cambió.
- Referencia directa a la barra de info, sin `viewWithTag:`.
- Los guardados a disco, fuera del hilo principal.
- `CADisableMinimumFrameDurationOnPhone` activado para permitir 120 Hz.
- Modo "Watusi" que reproduce el método observado, para comparar en el mismo teléfono.
