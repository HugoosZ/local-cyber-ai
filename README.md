# EIAI: IA local para Windows

**Made by AI** — configuracion, lanzador y documentacion desarrollados con asistencia de IA. Ollama, Open WebUI y los modelos pertenecen a sus respectivos autores.

Chat local con **Ollama + Open WebUI**, preparado para una RTX 5070 de 12 GB y 32 GB de RAM. El modelo principal es `huihui_ai/qwen3.5-abliterated:9b`; el original `qwen3.5:9b` se puede descargar para comparar respuestas.

La variante de Huihui modifica Qwen para reducir rechazos. Es experimental: no garantiza responder todas las preguntas, conservar toda la calidad del original ni acertar en sus respuestas. No hay que entrenar un modelo para usar este proyecto.

## Inicio rapido

1. Instala **Docker Desktop** y completa su configuracion inicial con contenedores Linux y backend **WSL 2**, con el driver NVIDIA de Windows actualizado. Para usar `main.py` necesitas **Python 3.10 o posterior**; no hay paquetes que instalar con pip.
2. En la carpeta del repositorio, ejecuta **`python main.py`** (o `py -3 main.py`). Si Docker Desktop esta cerrado, el arranque intenta abrirlo y espera a que este listo. La primera vez descarga las imagenes y el modelo principal (unos 6,6 GB para el modelo, mas las imagenes). Las siguientes reutilizan lo descargado.
3. El navegador abre automaticamente **http://eiai.localhost:3000/** cuando el chat esta listo. Crea tu primer usuario administrador. El nombre, correo y contrasena son de esta instalacion local; no necesitas una cuenta de OpenAI ni una API key. No se envia un correo de verificacion.
4. Selecciona `huihui_ai/qwen3.5-abliterated:9b` y escribe tu pregunta.

Para clonar e iniciar (necesitas acceso al repositorio privado):

```powershell
git clone https://github.com/HugoosZ/local-cyber-ai.git
cd local-cyber-ai
python main.py
```

Tambien puedes hacer doble clic en **`Iniciar.cmd`**, que abre el mismo enlace y funciona sin Python. El arranque PowerShell directo sigue disponible:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-LocalAI.ps1
```

`ExecutionPolicy Bypass` se aplica solo a ese proceso. El proyecto no cambia la politica de ejecucion del equipo.

El primer usuario se convierte en administrador. El registro de cuentas adicionales queda cerrado. No se configura ninguna contrasena predeterminada.

## Nombre local EIAI

`eiai.localhost` es un nombre local reconocido por los navegadores modernos. No se cambia el DNS de Windows, no se modifica el archivo `hosts` y no se requieren permisos de administrador para crear el nombre. Tampoco hay un registro que comprar o un servicio DNS externo del que depender.

Cada persona que clone y arranque el proyecto abrira **su propia instancia en su PC** mediante `http://eiai.localhost:3000/`. El puerto se obtiene de `WEBUI_PORT` en `.env`: si lo cambias a 3100, el lanzador abre `http://eiai.localhost:3100/`. La direccion original `http://127.0.0.1:3000/` sigue funcionando. El cambio de nombre puede pedirte iniciar sesion otra vez por las cookies del navegador; tus cuentas y conversaciones siguen en los mismos volumenes Docker.

Opciones del lanzador:

```powershell
python main.py --no-browser
python main.py --with-comparison
```

La primera inicia sin abrir una pestana. La segunda descarga ademas Qwen original. El navegador se abre solo despues de completar el arranque y comprobar que WebUI responde. `main.py` tambien funciona si lo ejecutas desde otra carpeta usando su ruta completa.

## Que se ejecuta

| Servicio | Funcion | Acceso |
| --- | --- | --- |
| `ollama` | Ejecuta el modelo con NVIDIA GPU | Solo la red interna de Compose; sin puerto publicado |
| `open-webui` | Chat, cuenta e historial | `eiai.localhost:3000`, enlazado a `127.0.0.1`, solo este PC |

La interfaz no usa GPU para inferencia: Ollama es el servicio que recibe la RTX. Hay una sola generacion y un modelo cargado a la vez, con contexto inicial de **65536 tokens (64K)**, probado completamente en GPU en una RTX 5070 de 12 GB. El contexto incluye instrucciones, historial y respuesta; no es una memoria infinita.

Para el chat normal no se fija un tope adicional de salida (`max_tokens` o `num_predict`). Ollama conserva su comportamiento sin un tope de generacion explicito; la respuesta aun debe terminar dentro del contexto y la memoria disponible. La prueba automatica de aritmetica usa un limite pequeno solo para esa peticion de diagnostico.

El razonamiento extendido esta desactivado por defecto (`think=false`) para evitar esperas largas en preguntas sencillas. Puedes activarlo para una consulta que lo necesite desde los parametros de razonamiento del chat. Esta opcion controla cuanto razona el modelo, no sus restricciones de contenido.

No se configura busqueda web, proveedor OpenAI, modelos cloud, terminal ni ejecucion de codigo. Puedes pedir y leer codigo en el chat; este proyecto no lo ejecuta. Las conexiones directas a proveedores y los plugins estan deshabilitados en la configuracion inicial.

Las herramientas integradas de WebUI tambien estan desactivadas por defecto mediante `DEFAULT_MODEL_METADATA`: desactivar plugins por si solo no desactiva herramientas como `ask_user`. El chat de texto no necesita esos esquemas, que pueden ocupar gran parte de un contexto de 8192 tokens. Se usan parametros de muestreo para Qwen3.5 en modo sin razonamiento; al cambiar de familia de modelo conviene revisarlos.

`OFFLINE_MODE=true` evita las descargas automaticas de Hugging Face y la comprobacion de versiones de WebUI. **El proyecto no bloquea la red del sistema**: la descarga de imagenes y modelos necesita internet. Tras descargar todo, el chat local puede funcionar sin conexion. No se ha configurado RAG, embeddings ni analisis de PDF/Office; para esta primera version, pega el texto, codigo o logs en el chat. El administrador puede cambiar ajustes de WebUI, que se guardan en su base de datos.

## Credenciales y archivos privados

- El script genera una clave aleatoria de 32 bytes en **`.env`**, usado para firmar sesiones de WebUI. No muestra la clave ni la envia a GitHub.
- Tu usuario y contrasena de WebUI se crean en la interfaz. La base de datos guarda el hash de la contrasena en un volumen Docker.
- No necesitas tokens de OpenAI, Ollama ni Docker Hub para descargar estas imagenes y modelos publicos.
- GitHub requiere tu propia sesion para crear o acceder al repositorio privado; esa sesion no forma parte del proyecto.
- `.gitignore` excluye `.env`, pesos, bases de datos, logs y respaldos. Un repositorio privado tambien debe mantenerse libre de secretos.

Conserva una copia privada de `.env`: cambiar la clave puede invalidar las sesiones. No adjuntes a issues la salida completa de `docker compose config`, porque incluye las variables resueltas. Usa `docker compose config --quiet` si solo quieres validar la sintaxis.

## Comparar con Qwen original

```powershell
python main.py --with-comparison
```

Esto descarga tambien `qwen3.5:9b`. Puedes elegir cualquiera desde WebUI. Solo se mantiene un modelo cargado a la vez; cambiar de modelo puede tardar unos segundos. Los tags de modelos pueden cambiar en el registro: revisa `VALIDATION.md` para ver los identificadores probados en esta instalacion.

## Cambiar de modelo

El modelo no se importa desde Python: Ollama lo ejecuta como un servicio independiente. Para sustituirlo por otro compatible:

1. Cambia `PRIMARY_MODEL` en tu `.env` por el identificador del modelo de Ollama.
2. Ejecuta `python main.py`. El arranque descarga el modelo si todavia no esta instalado.
3. Selecciona el nuevo modelo en el chat de WebUI. Sus ajustes persistidos pueden conservar la seleccion anterior aunque cambie el valor inicial del entorno.

El lanzador, la interfaz y las cuentas se conservan. El modelo anterior permanece en disco hasta que lo elimines expresamente. Para que las nuevas instalaciones usen otro modelo, actualiza tambien `PRIMARY_MODEL` en `.env.example`; ese archivo no sobrescribe el `.env` de una instalacion existente.

Normalmente basta con ese cambio de configuracion, siempre que el modelo quepa en la memoria disponible y lo soporte la version instalada de Ollama. Una arquitectura mas nueva puede requerir actualizar la imagen de Ollama en `compose.yaml`; otros modelos pueden necesitar distintos ajustes de contexto o razonamiento (`think`). Menor consumo de memoria no garantiza la misma calidad en todas las tareas. Compara sus respuestas antes de adoptarlo como predeterminado.

## Comprobar funcionamiento

```powershell
# Salud de servicios y modelos disponibles
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LocalAI.ps1

# Ademas genera una respuesta de prueba y muestra donde se cargo el modelo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LocalAI.ps1 -Inference
```

El resultado de `ollama ps` deberia indicar `100% GPU`. El tamano del archivo del modelo no es su consumo total: contexto, caches, escritorio y juegos tambien ocupan VRAM. No se promete una velocidad de generacion sin medir.

La prueba de inferencia es una pregunta aritmetica acotada, sin razonamiento extendido: comprueba conexion, generacion y uso de GPU; no evalua la competencia del modelo en ciberseguridad.

## Detener y volver a iniciar

Haz doble clic en **`Detener.cmd`** para detener los servicios conservando cuentas, chats y modelos. Usa **`python main.py`** o **`Iniciar.cmd`** para volver a arrancarlos. Si esta instalado pero cerrado, el arranque intenta abrir Docker Desktop y espera hasta 120 segundos. Si requiere configuracion inicial o una actualizacion de WSL, completa ese paso en su ventana y vuelve a ejecutar el inicio.

Los datos viven en estos volumenes Docker:

- `local-cyber-ai_ollama-data`: modelos y datos de Ollama.
- `local-cyber-ai_webui-data`: usuarios, conversaciones y ajustes de WebUI.

No ejecutes `docker compose down -v` ni elimines esos volumenes si quieres conservar los datos. El repositorio de GitHub no respalda los volumenes. Antes de actualizar, detiene los servicios y respalda ambos volumenes con el mecanismo de exportacion de Docker Desktop, junto con `.env` en un lugar privado. Verifica la restauracion antes de borrar una instalacion anterior.

## Ajustes de memoria y puerto

Edita `.env` y vuelve a ejecutar `Iniciar.cmd`:

- `WEBUI_PORT=3000`: cambia el puerto si ya esta ocupado. La escucha sigue limitada a `127.0.0.1`.
- `OLLAMA_CONTEXT_LENGTH=65536`: contexto de 64K probado en este equipo. Si falta VRAM, baja a 32768, 16384 u 8192. Otros modelos, GPUs o aplicaciones pueden consumir mas memoria; aumentar este numero requiere volver a medir.
- `OLLAMA_NUM_PARALLEL=1` y `OLLAMA_MAX_LOADED_MODELS=1`: punto de partida para 12 GB. Subirlos consume mas memoria y no da prioridad a un usuario.
- `PRIMARY_MODEL`: modelo que se descarga e indica como predeterminado. Si tienes poca memoria, puedes probar `qwen3.5:4b`.

Algunos ajustes de WebUI son persistentes: una vez guardados en la interfaz, pueden tener prioridad sobre las variables de arranque. No uses `ENABLE_PERSISTENT_CONFIG=false` como solucion habitual: los cambios de la interfaz dejarian de guardarse.

Tambien se probo `OLLAMA_CONTEXT_LENGTH=131072` (128K) con Huihui 9B: permanecio 100% en GPU, pero dejo aproximadamente 750 MiB libres en ese momento. Es una opcion para priorizar contexto con pocas aplicaciones usando GPU. El ejemplo del repositorio conserva 64K para dejar mas margen; tu `.env` privado puede usar 128K. Si juegas al mismo tiempo, reduce el contexto o detiene la IA.

## Si Docker o la GPU fallan

1. Confirma que Docker Desktop termino de arrancar y usa Linux/WSL 2.
2. Actualiza el driver **NVIDIA de Windows** y WSL si es necesario. No instales un driver NVIDIA de Linux dentro de WSL para este proyecto.
3. Si la prueba de acceso GPU falla, el script se detiene y muestra el error; no cambia silenciosamente a CPU.
4. Para diagnosticar arranque: `docker compose ps` y `docker compose logs --tail 80 ollama open-webui`. Revisa y anonimiza cualquier salida antes de compartirla.

## Si aparecen herramientas o respuestas cortadas

Si actualizas una instalacion anterior y ves `View Result from ask_user`, o respuestas que se cortan a mitad de palabra aun en chats cortos, aplica los nuevos valores al volumen existente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Repair-ChatDefaults.ps1
```

El script detiene brevemente solo WebUI, respalda su base de datos en la carpeta privada `backups` del volumen `webui-data`, aplica los defaults de chat del Compose y vuelve a iniciar WebUI. No edita cuentas ni conversaciones. Despues abre **un chat nuevo**, ya que el anterior puede contener resultados de herramientas e instrucciones antiguas. Una configuracion explicita de un modelo personalizado puede prevalecer sobre los defaults globales: revisa su capacidad Builtin Tools si lo has personalizado.

El limite de contexto incluye entrada y salida. En la configuracion anterior, 7916 tokens de entrada en un contexto de 8192 dejaban solo 276 para responder. Ahora el valor inicial es 64K, y ademas se retiraron las herramientas innecesarias. Aumentar el contexto no mejora por si solo el conocimiento del modelo. En una instalacion existente, cambia tambien `OLLAMA_CONTEXT_LENGTH=65536` en tu `.env` y ejecuta `python main.py`: `.env.example` no sobrescribe tu configuracion privada.

Una respuesta completa tampoco garantiza precision: la variante Huihui puede inventar datos tecnicos. Compara con Qwen original mediante `python main.py --with-comparison` y selecciona `qwen3.5:9b` en el chat. El modelo original puede tener un comportamiento de rechazo distinto. No se modifica automaticamente tu eleccion de modelo principal.

## Compartir con amigos

Compartir el repositorio permite que cada persona lo ejecute en su propio PC. En ese caso cada instalacion genera su propia clave y crea su usuario.

Esta version no publica tu instancia a la LAN ni a internet. Para compartir tu GPU mas adelante, configura una VPN como Tailscale y cuentas individuales de WebUI. Todos compartirian la misma capacidad; la cola de Ollama no garantiza prioridad al propietario.

## Versiones y componentes

- Ollama: `ollama/ollama:0.40.16`.
- Open WebUI: `ghcr.io/open-webui/open-webui:v0.13.3`.
- Modelo principal: `huihui_ai/qwen3.5-abliterated:9b`, cuantizacion Q4_K_M publicada por el autor.
- Modelo de comparacion: `qwen3.5:9b`, opcional.

Las imagenes tienen versiones fijadas; no hay actualizaciones automaticas. Para actualizar, respalda primero, revisa las notas de version y cambia los tags en `compose.yaml`. Una nueva version de WebUI puede migrar la base de datos: volver a una imagen anterior puede requerir restaurar el respaldo.

Los componentes y pesos se descargan de sus autores y mantienen sus propias licencias. Este repositorio conserva el nombre y branding de Open WebUI y no redistribuye los pesos.

## Fuentes oficiales

- [Docker Desktop: GPU en Windows/WSL 2](https://docs.docker.com/desktop/features/gpu/)
- [Microsoft: nombres locales con .localhost](https://learn.microsoft.com/en-us/aspnet/core/test/localhost-tld)
- [Ollama en Docker](https://docs.ollama.com/docker)
- [Contexto y memoria en Ollama](https://docs.ollama.com/context-length)
- [Open WebUI: instalacion](https://docs.openwebui.com/getting-started/quick-start/)
- [Open WebUI: variables de entorno](https://docs.openwebui.com/reference/env-configuration/)
- [Huihui Qwen3.5 9B: ficha del autor](https://huggingface.co/huihui-ai/Huihui-Qwen3.5-9B-abliterated)
- [Qwen3.5 9B original](https://huggingface.co/Qwen/Qwen3.5-9B)
- [Licencia de Open WebUI](https://docs.openwebui.com/license/)
