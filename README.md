# FocoCazador

Addon para **WoW Forever** que hace que el maná de los cazadores se vea como **enfoque**: barra naranja, igual que la de las mascotas. El recurso sigue siendo maná; solo cambia el aspecto.

## Qué hace

- **Tu barra (si eres cazador):** la barra de maná del marco de jugador pasa a naranja, y el trozo de coste del hechizo que estás lanzando se ve en naranja claro.
- **Otros cazadores:** en los marcos de objetivo, objetivo del objetivo, foco, grupo y banda, el maná de cualquier jugador cazador se muestra en naranja (también si juegas con otra clase).

## Instalación

Copia la carpeta `FocoCazador` en `World of Warcraft/_forever_/Interface/AddOns/` y reinicia el juego.

## Comandos

| Comando | Efecto |
|---|---|
| `/foco` | Estado del addon |
| `/foco modo liso \| mascota \| tinte` | Estilo de la barra (`liso` por defecto) |
| `/foco color R G B` | Color de la barra (0-255), `/foco color reset` para volver al de serie |
| `/foco coste R G B` | Color del coste del hechizo, `/foco coste reset` |
| `/foco ayuda` | Lista de comandos |

## Notas técnicas

WoW Forever usa marcos propios sin nombre y "valores secretos" (no se pueden comparar los valores de las barras), así que la barra de maná se localiza por posición dentro del `PlayerFrame`. En los marcos que se reutilizan para cualquier unidad no se toca la barra original: se superpone una barra propia que copia su valor y solo se muestra cuando la unidad es un cazador.
