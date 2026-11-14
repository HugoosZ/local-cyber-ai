"""Start EIAI on Windows and open its local browser address.

Only Python's standard library is needed. Docker and model setup remain in the
PowerShell startup script so both entry points use the same configuration.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import ProxyHandler, build_opener
import webbrowser


PROJECT_ROOT = Path(__file__).resolve().parent
DEFAULT_PORT = 3000
BROWSER_HOST = "eiai.localhost"


def read_port(environment_file: Path) -> int:
    """Read only the port setting; never print or return other .env values."""
    if not environment_file.exists():
        return DEFAULT_PORT

    raw_port: str | None = None
    with environment_file.open(encoding="utf-8-sig") as source:
        for line in source:
            match = re.match(r"^\s*WEBUI_PORT\s*=\s*(.*?)\s*$", line)
            if match:
                raw_port = match.group(1)

    if raw_port is None:
        return DEFAULT_PORT
    if raw_port.startswith(("'", '"')):
        quote = raw_port[0]
        end = raw_port.find(quote, 1)
        if end < 0:
            raise ValueError("WEBUI_PORT tiene comillas sin cerrar en .env.")
        suffix = raw_port[end + 1 :].strip()
        if suffix and not suffix.startswith("#"):
            raise ValueError("WEBUI_PORT contiene texto no valido en .env.")
        value = raw_port[1:end]
    else:
        value = re.split(r"\s+#", raw_port, maxsplit=1)[0].strip()

    if not re.fullmatch(r"[0-9]+", value):
        raise ValueError("WEBUI_PORT debe ser un entero entre 1 y 65535 en .env.")
    port = int(value)
    if not 1 <= port <= 65535:
        raise ValueError("WEBUI_PORT debe ser un entero entre 1 y 65535 en .env.")
    return port


def powershell_path() -> str:
    executable = shutil.which("powershell.exe")
    if executable:
        return executable
    candidate = (
        Path(os.environ.get("SystemRoot", r"C:\Windows"))
        / "System32"
        / "WindowsPowerShell"
        / "v1.0"
        / "powershell.exe"
    )
    if candidate.is_file():
        return str(candidate)
    raise FileNotFoundError("No se encontro Windows PowerShell en este equipo.")


def start_stack(project_root: Path, with_comparison: bool) -> int:
    startup_script = project_root / "scripts" / "Start-LocalAI.ps1"
    if not startup_script.is_file():
        raise FileNotFoundError("Falta scripts/Start-LocalAI.ps1 en el proyecto.")
    command = [
        powershell_path(),
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(startup_script),
    ]
    if with_comparison:
        command.append("-WithComparison")
    return subprocess.run(command, cwd=str(project_root), check=False).returncode


def wait_for_health(port: int, timeout_seconds: float = 30.0) -> None:
    # The health check always uses loopback, even if the browser resolves the
    # friendly name itself. Ignore proxy environment variables for this request.
    opener = build_opener(ProxyHandler({}))
    health_url = f"http://127.0.0.1:{port}/health"
    deadline = time.monotonic() + timeout_seconds
    last_problem = "sin respuesta"
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        try:
            with opener.open(health_url, timeout=min(5.0, remaining)) as response:
                status = response.getcode()
                if status == 200:
                    return
                last_problem = f"HTTP {status}"
        except (URLError, OSError, TimeoutError) as error:
            last_problem = str(error)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(0.5, remaining))
    raise RuntimeError(
        f"WebUI no responde en {health_url}: {last_problem}. "
        "Revisa Docker Desktop y la salida del arranque."
    )


def main(argv: list[str] | None = None, *, project_root: Path | None = None) -> int:
    parser = argparse.ArgumentParser(description="Inicia EIAI y abre su chat local.")
    parser.add_argument(
        "--no-browser", action="store_true", help="Iniciar sin abrir el navegador."
    )
    parser.add_argument(
        "--with-comparison",
        action="store_true",
        help="Descargar tambien Qwen original para comparar respuestas.",
    )
    args = parser.parse_args(argv)

    if sys.platform != "win32":
        print("Este lanzador esta preparado para Windows.", file=sys.stderr)
        return 1
    root = (project_root if project_root is not None else PROJECT_ROOT).resolve()

    try:
        result = start_stack(root, args.with_comparison)
        if result != 0:
            print(
                "No se pudo completar el arranque. Revisa el mensaje anterior.",
                file=sys.stderr,
            )
            return result
        # Startup creates .env on the first run. Read the actual setting after it
        # succeeds, rather than assuming the initial installation's default port.
        port = read_port(root / ".env")
        wait_for_health(port)
    except KeyboardInterrupt:
        print("Arranque interrumpido.", file=sys.stderr)
        return 130
    except (OSError, ValueError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    url = f"http://{BROWSER_HOST}:{port}/"
    print(f"EIAI esta listo: {url}")
    if not args.no_browser:
        try:
            opened = webbrowser.open(url, new=2)
        except (webbrowser.Error, OSError):
            opened = False
        if not opened:
            print("No se pudo abrir el navegador automaticamente. Abre el enlace anterior.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
