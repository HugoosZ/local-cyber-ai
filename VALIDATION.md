# Validacion

Este archivo registra comprobaciones reales, sin secretos ni datos de conversaciones. La presencia de configuracion por si sola no demuestra que la GPU este en uso.

## Configuracion de referencia

- Windows 11, Docker Desktop con contenedores Linux/WSL 2.
- RTX 5070 de 12 GB.
- Contexto 8192, una generacion y un modelo cargado a la vez.
- Modelo principal: `huihui_ai/qwen3.5-abliterated:9b`.

## Resultados del 14 de noviembre de 2026

Comprobaciones ejecutadas en el equipo de instalacion:

| Comprobacion | Resultado |
| --- | --- |
| Docker Desktop | 4.95.0, Engine 29.8.2, contenedores Linux |
| Docker Compose | 5.6.0 |
| WSL | 3.0.5.0, backend WSL 2 |
| Driver NVIDIA | 621.14 |
| GPU visible dentro de un contenedor Ollama | RTX 5070, 12227 MiB |
| Validacion Compose | `docker compose config --quiet`: correcta |
| Salud de Ollama y Open WebUI | Ambos contenedores `healthy` |
| WebUI `/health` | HTTP 200 |
| WebUI `/api/config` | HTTP 200, formulario de acceso activo y registro adicional deshabilitado |
| WebUI `/api/models` sin sesion | HTTP 401, autenticacion requerida |
| Descarga del modelo principal | Correcta, 6,6 GB; verificacion SHA-256 de Ollama finalizada |
| Inferencia desde el contenedor WebUI hacia Ollama | Pregunta `2 + 2`, respuesta final `4` |
| Prueba acotada | `think=false`, `num_predict=64`, `temperature=0`, `num_ctx=8192` |
| Carga despues de generar | `100% GPU`, contexto 8192, runner `llamacpp` |
| Arranque repetido | Reutiliza el modelo instalado sin consultar el registro |
| PowerShell 5.1 | Sintaxis, generacion de secreto, idempotencia, validacion de puerto y tratamiento de errores nativos comprobados |
| Secretos | `.env` excluido de Git; no se incluye una contrasena de administrador |

La prueba corta devolvio 2 tokens con 0,02 s de tiempo de generacion informado por Ollama. **No es un benchmark**: esa metrica excluye arranque y otros tiempos, y no representa rendimiento en conversaciones largas o analisis tecnico.

## Identificadores descargados

- Modelo principal, ID corto: `92a443adb124`.
- Imagen Ollama: `ollama/ollama@sha256:910d0d8107b538fb0894e63163eb195de0cc7aefcbc666dc62d3b18f71124592`.
- Imagen WebUI: `ghcr.io/open-webui/open-webui@sha256:46b59158e6558eeb980bc828e0f1b30238ad24d82ed84d5e5eda1dab2a082f14`.

Compose fija versiones semanticas. Los digest anteriores documentan las imagenes resueltas en esta instalacion; el ID del modelo permite detectar cambios futuros del tag.

## Alcance de las pruebas

No se creo una cuenta de usuario: el propietario debe crear su administrador en la interfaz. La inferencia se comprobo por API desde la red interna Docker, no desde una sesion de chat autenticada. El modelo original opcional no se descargo. Tampoco se ha evaluado la calidad del modelo en un incidente real, ni se han habilitado acceso remoto, busqueda web o herramientas de ejecucion.
