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

## Lanzador EIAI

Comprobado el 14 de noviembre de 2026:

- `python main.py` ejecutado con Python 3.12 de Windows desde otra carpeta: completo el arranque y abrio `http://eiai.localhost:3000/` mediante el navegador predeterminado.
- `http://eiai.localhost:3000/health` devolvio HTTP 200 usando curl de Windows sin proxy.
- Windows resolvio `eiai.localhost` a `::1` y `127.0.0.1`. No se modificaron DNS ni `hosts`.
- Los servicios existentes siguieron `healthy`; el modelo instalado se reutilizo.
- Pasaron 11 pruebas Python: puerto personalizado e invalido, rutas con espacios y cambio de carpeta, propagacion de errores, health sin proxies, apertura del navegador solo tras exito y opciones de linea de comandos.
- Sintaxis PowerShell 5.1 correcta. En fixtures se verificaron Docker ya listo, Desktop cerrado, Desktop iniciandose y ejecutable ausente, sin detener servicios reales.
- Se alineo la lectura de valores `.env` entre PowerShell y Python, comprobando un puerto entre comillas seguido de comentario.

Los casos de Docker Desktop cerrado se probaron con mocks: no se cerro Docker Desktop en este equipo para no interrumpir otras aplicaciones. La prueba de integracion uso el motor que ya estaba en marcha. No se evaluo nuevamente la calidad del modelo para este cambio de nombre y arranque.

## Alcance de las pruebas

No se creo una cuenta de usuario: el propietario debe crear su administrador en la interfaz. La inferencia se comprobo por API desde la red interna Docker, no desde una sesion de chat autenticada. El modelo original opcional no se descargo. Tampoco se ha evaluado la calidad del modelo en un incidente real, ni se han habilitado acceso remoto, busqueda web o herramientas de ejecucion.

## Correccion del 15 de noviembre de 2026

Se diagnosticaron dos problemas distintos: consumo de contexto por herramientas integradas de WebUI y errores factuales del modelo.

- En una respuesta cortada, los metadatos mostraron 7916 tokens de entrada y 276 de salida: se agoto exactamente el contexto anterior de 8192. No habia un pequeno tope global de salida configurado.
- `ENABLE_PLUGINS=false` no desactivaba los built-ins. Se agrego `DEFAULT_MODEL_METADATA` con `capabilities.builtin_tools=false`, tanto para instalaciones nuevas como para el volumen existente mediante `Repair-ChatDefaults.ps1`.
- La reparacion creo un respaldo SQLite privado en el volumen antes de actualizar solo `models.default_metadata` y `models.default_params`. WebUI volvio a estado healthy; las cuentas y conversaciones se conservaron.
- El script de comprobacion ahora detecta si el volumen conserva las herramientas internas activadas por defecto.
- Se aplicaron parametros de muestreo para Qwen3.5 sin razonamiento extendido. No se establecio un tope adicional de salida para el chat normal.
- Se descargaron y compararon Huihui y Qwen3.5 9B original con preguntas tecnicas inocuas, sin historial ni herramientas. Ambos completaron esas respuestas con `done_reason=stop`. Huihui siguio inventando algunos detalles en preguntas abiertas; esta correccion no demuestra resolver las alucinaciones del modelo.
- La pregunta directa sobre montar una IA local uso 81 tokens de entrada, frente a miles en las conversaciones anteriores. Esto es una prueba directa por API, no una medicion de una sesion visual completa de WebUI.
- Se probaron contextos 32768, 65536 y 131072. Con 128K, Huihui respondio `OK`, `ollama ps` indico 100% GPU y contexto 131072, y se midieron aproximadamente 11480 MiB de los 12227 MiB de VRAM ocupados. Son mediciones puntuales, no una garantia de margen bajo otras cargas.
- La instalacion del propietario se ajusta a 128K en su `.env` privado. La configuracion inicial del repositorio usa 64K para dejar mas margen.
- Tras aplicar el valor privado y recrear Ollama, `Test-LocalAI.ps1 -Inference` paso: herramientas desactivadas, respuesta `4`, 100% GPU y contexto 131072. No habia `max_tokens` ni `num_predict` en los parametros globales de chat. Qwen original quedo instalado con ID corto `56671c2ab938`; Huihui se conservo como principal.
- `Repair-ChatDefaults.ps1` paso parser PowerShell 5.1 y fixtures de SQLite: respaldo previo, claves adicionales preservadas, usuarios/chats intactos, repeticion idempotente y errores ante DB ausente o JSON invalido. La secuencia de restauracion de WebUI se verifico tambien con mocks.

Las pruebas del dia anterior siguen describiendo la instalacion inicial. El 15 de noviembre ya habia usuarios y conversaciones; no se utilizaron sus textos en las pruebas de generacion ni se publicaron datos del volumen.
