# ReadTube

## Claude es el backend LLM

Martin no tiene Ollama corriendo ni API keys seteadas. Para modos `article` / `tldr` / `takeaways`: bajar el transcript y escribirlo yo. **No preguntar por backends.**

Flujo:
1. Correr `readtube "URL" --mode transcript` con el path absoluto del `.venv` (ver abajo) y el `--lang` correcto (ver "Idioma" abajo).
2. Escribir el artículo siguiendo `SKILL.md` (headline propio, magazine style, sin "en este video", sin la publicidad del sponsor). **El artículo va en el mismo idioma del transcript.**
3. Mostrar en el chat. Guardar a archivo solo si lo pide.

Modo `transcript` puro: correr `--mode transcript` y mostrar el output tal cual, sin procesar.

## Idioma

Sin `--lang`, readtube agarra el primer track disponible — frecuentemente subtítulos en inglés (auto-traducidos o manuales) aun cuando el audio del video sea otro idioma. Esto deriva en artículos en idioma equivocado.

**Antes de correr:** chequear el idioma del video (título, canal, descripción) y pasar `--lang` explícito si no es inglés. Para canales hispanohablantes: `--lang es`. Si hay duda, preguntar a Martin antes de bajar.

El binario no está en el PATH global — usar siempre el path absoluto del `.venv` según la máquina:
- **Mac (M2):** `/Users/martinwagner/Projects/ReadTube/.venv/bin/readtube`
- **Book5 (Windows):** `C:\Users\marti\Projects\readtube\.venv\Scripts\readtube.exe`
