# ReadTube

## Claude es el backend LLM

Martin no tiene Ollama corriendo ni API keys seteadas. Para modos `article` / `tldr` / `takeaways`: bajar el transcript y escribirlo yo. **No preguntar por backends.**

Flujo:
1. `/Users/martinwagner/Projects/ReadTube/.venv/bin/readtube "URL" --mode transcript`
2. Escribir el artículo siguiendo `SKILL.md` (headline propio, magazine style, sin "en este video", sin la publicidad del sponsor).
3. Mostrar en el chat. Guardar a archivo solo si lo pide.

Modo `transcript` puro: correr `--mode transcript` y mostrar el output tal cual, sin procesar.

El binario no está en el PATH global — usar siempre el path absoluto del `.venv`.
