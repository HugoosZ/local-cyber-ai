# EIAI: IA local para Windows

**Made by AI** — configuracion, lanzador y documentacion desarrollados con asistencia de IA. Ollama, Open WebUI y los modelos pertenecen a sus respectivos autores.

Chat local con **Ollama + Open WebUI**, preparado para una RTX 5070 de 12 GB y 32 GB de RAM. El modelo principal es **`gemma4:12b`**, de Google. `gemma4:31b` es la opcion oficial mayor para comparar respuestas.

Gemma sustituyo a Huihui como opcion principal tras pruebas locales de comprension, logica y programacion. Eso no garantiza respuestas correctas en todos los casos ni equivalencia con servicios cloud. Es un modelo oficial y su comportamiento de rechazo puede diferir del modelo modificado de Huihui. Los modelos anteriores no se borran al actualizar. No hay que entrenar un modelo para usar este proyecto.

## Modelos para elegir

| Modelo | Uso | Contexto del perfil |
| --- | --- | --- |
| Gemma 4 12B - rapido (`gemma4:12b`) | Opcion inicial, pensada para ejecutarse en la RTX de 12 GB | 65536 (64K) |
| Gemma 4 31B - grande (`gemma4:31b`) | Opcion oficial mayor, usa GPU y RAM y tarda mas | 8192 (8K) |

El selector de WebUI permite cambiar entre los modelos instalados. Solo se carga uno a la vez. El perfil grande prioriza capacidad del modelo sobre longitud del historial: sus pesos de unos 20 GB no caben enteros en 12 GB de VRAM. El mayor tamano no garantiza acertar siempre. Revisa `VALIDATION.md` para distinguir lo que se midio de lo que es solo una expectativa.

En las pruebas cortas de este equipo, 12B genero unos 64-66 tokens/s sin razonamiento y 31B unos 3,7-3,9 tokens/s. El primer arranque de 31B tardo unos 58 segundos en cargar; una pregunta matematica con razonamiento tardo unos 66 segundos con el modelo ya cargado. Durante su carga Windows llego a tener solo unos 0,3 GB de RAM libre. Por eso 12B sigue como inicio y 31B queda como opcion ocasional. Son mediciones puntuales, no un benchmark comparativo de calidad.

`python main.py` descarga solo el principal. **`python main.py --with-comparison`** descarga tambien el modelo de comparacion de `.env`, inicialmente Gemma 31B. Cada instalacion necesita espacio para ambos modelos si habilita esa opcion. El lanzador abre explicitamente el modelo de `PRIMARY_MODEL` mediante un parametro en el enlace.

`model-profiles.json` guarda parametros por modelo, incluido su contexto. El arranque aplica los perfiles de los modelos ya descargados a traves de las APIs internas de Open WebUI. Se hace un respaldo SQLite privado antes de cambiar perfiles; se conservan cuentas y conversaciones. Los perfiles nuevos pertenecen al administrador inicial y no se publican para otros usuarios. Si aun no existe una cuenta, crea el primer administrador y vuelve a ejecutar el inicio para aplicar los perfiles.

Los parametros especificos de un modelo prevalecen sobre los globales. Un ajuste propio de un chat puede prevalecer a su vez. Al cambiar `PRIMARY_MODEL`, revisa tambien el perfil correspondiente. `OLLAMA_CONTEXT_LENGTH` es el valor de respaldo para modelos sin `num_ctx` propio; los perfiles de arriba lo reemplazan al chatear.

## Inicio rapido

1. Instala **Docker Desktop** y completa su configuracion inicial con contenedores Linux y backend **WSL 2**, con el driver NVIDIA de Windows actualizado. Para usar `main.py` necesitas **Python 3.10 o posterior**; no hay paquetes que instalar con pip.
2. En la carpeta del repositorio, ejecuta **`python main.py`** (o `py -3 main.py`). Si Docker Desktop esta cerrado, el arranque intenta abrirlo y espera a que este listo. La primera vez descarga las imagenes y el modelo principal (unos 8 GB para el modelo, mas las imagenes). Las siguientes reutilizan lo descargado.
3. El navegador abre automaticamente **http://eiai.localhost:3000/** cuando el chat esta listo. Crea tu primer usuario administrador. El nombre, correo y contrasena son de esta instalacion local; no necesitas una cuenta de OpenAI ni una API key. No se envia un correo de verificacion.
4. Tras crear el administrador, ejecuta de nuevo **`python main.py`** para aplicar los perfiles por modelo. Selecciona **Gemma 4 12B - rapido** y escribe tu pregunta en un chat nuevo.

Para clonar e iniciar desde el repositorio publico:

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

La primera inicia sin abrir una pestana. La segunda descarga el modelo de `COMPARISON_MODEL`. El navegador se abre solo despues de completar el arranque y comprobar que WebUI responde. `main.py` tambien funciona si lo ejecutas desde otra carpeta usando su ruta completa.

## Que se ejecuta

| Servicio | Funcion | Acceso |
| --- | --- | --- |
| `ollama` | Ejecuta el modelo con NVIDIA GPU | Solo la red interna de Compose; sin puerto publicado |
| `open-webui` | Chat, cuenta e historial | `eiai.localhost:3000`, enlazado a `127.0.0.1`, solo este PC |

La interfaz no usa GPU para inferencia: Ollama es el servicio que recibe la RTX. Hay una sola generacion y un modelo cargado a la vez, con contexto inicial de **65536 tokens (64K)**, probado completamente en GPU en una RTX 5070 de 12 GB. El contexto incluye instrucciones, historial y respuesta; no es una memoria infinita.

Para el chat normal no se fija un tope adicional de salida (`max_tokens` o `num_predict`). Ollama conserva su comportamiento sin un tope de generacion explicito; la respuesta aun debe terminar dentro del contexto y la memoria disponible. La prueba automatica de aritmetica usa un limite pequeno solo para esa peticion de diagnostico.

El razonamiento esta activado en los perfiles (`think=true`). Gemma produjo una conclusion mas clara en la prueba de inferencia con ese modo, a cambio de mayor tiempo de respuesta. Puedes desactivarlo en los controles del chat, en los parametros avanzados de `think (Ollama)`, para obtener respuestas directas. Esta opcion no garantiza acertar.

No se configura busqueda web, proveedor OpenAI, modelos cloud, terminal ni ejecucion de codigo. Puedes pedir y leer codigo en el chat; este proyecto no lo ejecuta. Las conexiones directas a proveedores y los plugins estan deshabilitados en la configuracion inicial.

Las herramientas integradas de WebUI tambien estan desactivadas por defecto mediante `DEFAULT_MODEL_METADATA`: desactivar plugins por si solo no desactiva herramientas como `ask_user`. El chat de texto no necesita esos esquemas, que pueden ocupar gran parte de un contexto corto. El perfil de Gemma usa temperatura 1, top-p 0,95, top-k 64 y penalizacion de presencia 0. El modelo auxiliar de decodificacion esta desactivado (`draft_num_predict=0`) en este perfil para dejar mas margen en la RTX. Al cambiar de familia de modelo conviene revisar estos parametros globales.

`OFFLINE_MODE=true` evita las descargas automaticas de Hugging Face y la comprobacion de versiones de WebUI. **El proyecto no bloquea la red del sistema**: la descarga de imagenes y modelos necesita internet. Tras descargar todo, el chat local puede funcionar sin conexion. No se ha configurado RAG, embeddings ni analisis de PDF/Office; para esta primera version, pega el texto, codigo o logs en el chat. El administrador puede cambiar ajustes de WebUI, que se guardan en su base de datos.

## Credenciales y archivos privados

- El script genera una clave aleatoria de 32 bytes en **`.env`**, usado para firmar sesiones de WebUI. No muestra la clave ni la envia a GitHub.
- Tu usuario y contrasena de WebUI se crean en la interfaz. La base de datos guarda el hash de la contrasena en un volumen Docker.
- No necesitas tokens de OpenAI, Ollama ni Docker Hub para descargar estas imagenes y modelos publicos.
- Clonar este repositorio publico no requiere iniciar sesion en GitHub. Publicar cambios en tu cuenta requiere tu propia sesion, que no forma parte del proyecto.
- `.gitignore` excluye `.env`, pesos, bases de datos, logs y respaldos. Esos datos permanecen en cada instalacion.

Conserva una copia privada de `.env`: cambiar la clave puede invalidar las sesiones. No adjuntes a issues la salida completa de `docker compose config`, porque incluye las variables resueltas. Usa `docker compose config --quiet` si solo quieres validar la sintaxis.

## Descargar el modelo de comparacion

```powershell
python main.py --with-comparison
```

Esto descarga el modelo configurado en `COMPARISON_MODEL`, inicialmente `gemma4:31b`. Puedes elegir cualquiera desde WebUI. Solo se mantiene un modelo cargado a la vez; cambiar de modelo puede tardar bastante si tiene que leer pesos grandes desde disco. Los tags de modelos pueden cambiar en el registro: revisa `VALIDATION.md` para ver los identificadores probados en esta instalacion.

## Cambiar de modelo

El modelo no se importa desde Python: Ollama lo ejecuta como un servicio independiente. Para sustituirlo por otro compatible:

1. Cambia `PRIMARY_MODEL` en tu `.env` por el identificador del modelo de Ollama.
2. Ejecuta `python main.py`. El arranque descarga el modelo si todavia no esta instalado.
3. Selecciona el nuevo modelo en el chat de WebUI. Sus ajustes persistidos pueden conservar la seleccion anterior aunque cambie el valor inicial del entorno.

El lanzador, la interfaz y las cuentas se conservan. El modelo anterior permanece en disco hasta que lo elimines expresamente. Para que las nuevas instalaciones usen otro modelo, actualiza tambien `PRIMARY_MODEL` en `.env.example`; ese archivo no sobrescribe el `.env` de una instalacion existente.

Si actualizas desde la configuracion anterior de Huihui, cambia `PRIMARY_MODEL=gemma4:12b` en `.env`, ejecuta `python main.py` y aplica `scripts/Repair-ChatDefaults.ps1` para actualizar los parametros que WebUI ya guardo en su volumen. Despues selecciona Gemma en un chat nuevo. No reutilices el perfil del modelo anterior con Gemma sin revisarlo: los parametros predeterminados globales afectan a los modelos que no tengan ajustes propios.

Normalmente basta con ese cambio de configuracion, siempre que el modelo quepa en la memoria disponible y lo soporte la version instalada de Ollama. Una arquitectura mas nueva puede requerir actualizar la imagen de Ollama en `compose.yaml`; otros modelos pueden necesitar distintos ajustes de contexto o razonamiento (`think`). Menor consumo de memoria no garantiza la misma calidad en todas las tareas. Compara sus respuestas antes de adoptarlo como predeterminado.

## Comprobar funcionamiento

```powershell
# Salud de servicios y modelos disponibles
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LocalAI.ps1

# Ademas genera una respuesta de prueba y muestra donde se cargo el modelo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LocalAI.ps1 -Inference
```

El resultado de `ollama ps` muestra el reparto entre CPU y GPU. Para 12B se busca `100% GPU`; para 31B es esperable una mezcla y la comprobacion la acepta. Agrega `-RequireFullGPU` si quieres exigir que el modelo entero este en GPU. El tamano del archivo del modelo no es su consumo total: contexto, caches, escritorio y juegos tambien ocupan VRAM. No se promete una velocidad de generacion sin medir.

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
- `OLLAMA_CONTEXT_LENGTH=65536`: respaldo para modelos sin un contexto propio. Para Gemma 12B/31B cambia `params.num_ctx` en `model-profiles.json`; ese valor prevalece sobre `.env`. Si falta VRAM, reduce el contexto del perfil y vuelve a iniciar. Otros modelos, GPUs o aplicaciones pueden consumir mas memoria; aumentar el contexto requiere volver a medir.
- `OLLAMA_NUM_PARALLEL=1` y `OLLAMA_MAX_LOADED_MODELS=1`: punto de partida para 12 GB. Subirlos consume mas memoria y no da prioridad a un usuario.
- `PRIMARY_MODEL`: modelo que se descarga e indica como predeterminado. Los perfiles incluidos requieren comprobar la memoria disponible en cada equipo.

Algunos ajustes de WebUI son persistentes: una vez guardados en la interfaz, pueden tener prioridad sobre las variables de arranque. No uses `ENABLE_PERSISTENT_CONFIG=false` como solucion habitual: los cambios de la interfaz dejarian de guardarse.

Tambien se probo `OLLAMA_CONTEXT_LENGTH=131072` (128K) con Gemma 4 12B y `draft_num_predict=0`: permanecio 100% en GPU, pero se midieron unos 11700 MiB usados de 12227 MiB en ese momento. Es una opcion con poco margen para otras aplicaciones. El perfil de 12B conserva 64K, incluso si el `.env` privado mantiene 128K como respaldo. Para cambiar el contexto de un perfil edita su `num_ctx` en `model-profiles.json` y vuelve a iniciar. La prueba verifico asignacion y generacion corta, no la calidad al procesar un documento de 128K. Si juegas al mismo tiempo, reduce el contexto o detiene la IA.

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

Una respuesta completa tampoco garantiza precision. La configuracion inicial de Huihui invento datos tecnicos en las pruebas. El proyecto ahora recomienda los perfiles oficiales de Gemma y mantiene los modelos anteriores en disco si ya estaban descargados. Puedes comparar respuestas seleccionando otro modelo instalado en un chat nuevo. El comportamiento de rechazo puede variar entre modelos.

## Compartir con amigos

Compartir el repositorio permite que cada persona lo ejecute en su propio PC. En ese caso cada instalacion genera su propia clave y crea su usuario.

Esta version no publica tu instancia a la LAN ni a internet. Para compartir tu GPU mas adelante, configura una VPN como Tailscale y cuentas individuales de WebUI. Todos compartirian la misma capacidad; la cola de Ollama no garantiza prioridad al propietario.

## Versiones y componentes

- Ollama: `ollama/ollama:0.40.16`.
- Open WebUI: `ghcr.io/open-webui/open-webui:v0.13.3`.
- Modelo principal: `gemma4:12b`, cuantizacion Q4_K_M publicada en Ollama, ID probado `6114515d63c1`.
- Modelo de comparacion: `gemma4:31b`, opcional, con carga mixta CPU/GPU prevista.

Las imagenes tienen versiones fijadas; no hay actualizaciones automaticas. Para actualizar, respalda primero, revisa las notas de version y cambia los tags en `compose.yaml`. Una nueva version de WebUI puede migrar la base de datos: volver a una imagen anterior puede requerir restaurar el respaldo.

Los componentes y pesos se descargan de sus autores y mantienen sus propias licencias. Este repositorio conserva el nombre y branding de Open WebUI y no redistribuye los pesos.

## Fuentes oficiales

- [Docker Desktop: GPU en Windows/WSL 2](https://docs.docker.com/desktop/features/gpu/)
- [Microsoft: nombres locales con .localhost](https://learn.microsoft.com/en-us/aspnet/core/test/localhost-tld)
- [Ollama en Docker](https://docs.ollama.com/docker)
- [Contexto y memoria en Ollama](https://docs.ollama.com/context-length)
- [Open WebUI: instalacion](https://docs.openwebui.com/getting-started/quick-start/)
- [Open WebUI: variables de entorno](https://docs.openwebui.com/reference/env-configuration/)
- [Gemma 4 12B en Ollama](https://ollama.com/library/gemma4:12b)
- [Gemma 4 31B en Ollama](https://ollama.com/library/gemma4:31b)
- [Gemma: mejores practicas](https://github.com/google-gemma/docs/blob/main/docs/get-started/best-practices.md)
- [Licencia de Open WebUI](https://docs.openwebui.com/license/)
