# Hunter Focus Bar

*[Español más abajo](#español)*

A **WoW Forever** addon that makes hunter mana look like **Focus**: an orange bar, just like your pet's. The resource is still mana; only the look changes.

## Features

- **Your bar (on a hunter):** the player frame mana bar turns orange, and the cost of the spell you are casting is shown in light orange.
- **Other hunters:** on the target, target-of-target, focus, party and raid frames, any hunter player's mana is shown in orange (even when you play another class).
- No chat spam: the addon only prints something when you use `/hfb`.

## Installation

Copy the `HunterFocusBar` folder into `World of Warcraft/_forever_/Interface/AddOns/` and restart the game.

## Commands

`/foco` also works as an alias of `/hfb`.

| Command | Effect |
|---|---|
| `/hfb` | Addon status |
| `/hfb mode smooth \| pet \| tint` | Bar style (`smooth` by default) |
| `/hfb color R G B` | Bar color (0-255), `/hfb color reset` for the default |
| `/hfb cost R G B` | Spell cost color, `/hfb cost reset` |
| `/hfb help` | List of commands |

## Technical notes

WoW Forever uses its own unnamed unit frames and "secret values" (bar values cannot be compared), so the mana bar is found by its position inside `PlayerFrame`. Frames that are reused for any unit are never modified: an extra bar that mirrors their value is laid on top and only shown when the unit is a hunter.

---

## Español

Addon para **WoW Forever** que hace que el maná de los cazadores se vea como **enfoque**: una barra naranja, igual que la de las mascotas. El recurso sigue siendo maná; solo cambia el aspecto.

### Qué hace

- **Tu barra (si eres cazador):** la barra de maná del marco de jugador pasa a naranja, y el coste del hechizo que estás lanzando se ve en naranja claro.
- **Otros cazadores:** en los marcos de objetivo, objetivo del objetivo, foco, grupo y banda, el maná de cualquier jugador cazador se muestra en naranja (también si juegas con otra clase).
- Sin mensajes en el chat: solo escribe algo cuando usas `/hfb`.

### Instalación

Copia la carpeta `HunterFocusBar` en `World of Warcraft/_forever_/Interface/AddOns/` y reinicia el juego.

### Comandos

`/foco` funciona también como alias de `/hfb`. Los comandos se pueden escribir en español o en inglés.

| Comando | Efecto |
|---|---|
| `/hfb` | Estado del addon |
| `/hfb modo liso \| mascota \| tinte` | Estilo de la barra (`liso` por defecto) |
| `/hfb color R G B` | Color de la barra (0-255), `/hfb color reset` para volver al de serie |
| `/hfb coste R G B` | Color del coste del hechizo, `/hfb coste reset` |
| `/hfb ayuda` | Lista de comandos |

## License

[MIT](LICENSE)
