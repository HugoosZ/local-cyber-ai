[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

$restartWebUI = $false
$repairError = $null
$restartError = $null

try {
    $null = Get-LocalAISettings
    Assert-LocalAIDockerReady
    Write-Host 'Se detendra solo Open WebUI para reparar sus ajustes de chat.'
    Write-Host 'Se guardara una copia privada de la base de datos en el mismo volumen Docker.'

    # Use the environment resolved by Compose as the single source of defaults.
    # Single quotes inside Python preserve forwarding in Windows PowerShell 5.1.
    $repairCode = @'
import copy
import datetime
import json
import os
from pathlib import Path
import sqlite3

def read_desired(name):
    raw = os.environ.get(name)
    if not raw:
        raise SystemExit('Falta ' + name + '. Actualiza compose.yaml antes de reparar.')
    try:
        value = json.loads(raw)
    except (TypeError, ValueError):
        raise SystemExit(name + ' debe contener un objeto JSON valido.')
    if not isinstance(value, dict) or not value:
        raise SystemExit(name + ' debe contener un objeto JSON no vacio.')
    return value

def deep_merge(current, desired):
    result = copy.deepcopy(current)
    for key, value in desired.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result

desired = {
    'models.default_metadata': read_desired('DEFAULT_MODEL_METADATA'),
    'models.default_params': read_desired('DEFAULT_MODEL_PARAMS'),
}
database = Path('/app/backend/data/webui.db')
if not database.is_file():
    raise SystemExit('No existe la base de datos de WebUI. Ejecuta primero el inicio normal.')

connection = None
try:
    # mode=rw refuses to create an empty database when the path is incorrect.
    connection = sqlite3.connect(database.as_uri() + '?mode=rw', uri=True, timeout=30)
    current = {}
    for key in desired:
        row = connection.execute('SELECT value FROM config WHERE key = ?', (key,)).fetchone()
        if row is None:
            raise SystemExit('Falta el ajuste esperado ' + key + '. No se modifica la base de datos.')
        try:
            value = json.loads(row[0])
        except (TypeError, ValueError):
            raise SystemExit('El ajuste ' + key + ' no contiene JSON valido. No se modifica la base de datos.')
        if not isinstance(value, dict):
            raise SystemExit('El ajuste ' + key + ' no es un objeto JSON. No se modifica la base de datos.')
        current[key] = value

    backup_directory = database.parent / 'backups'
    backup_directory.mkdir(exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup_path = backup_directory / ('eiai-chat-defaults-' + stamp + '.db')
    # SQLite backup also includes committed WAL contents, unlike copying webui.db.
    backup = sqlite3.connect(str(backup_path))
    try:
        connection.backup(backup)
    finally:
        backup.close()

    merged = {
        'models.default_metadata': deep_merge(current['models.default_metadata'], desired['models.default_metadata']),
        'models.default_params': {**current['models.default_params'], **desired['models.default_params']},
    }
    with connection:
        for key, value in merged.items():
            changed = connection.execute(
                'UPDATE config SET value = ? WHERE key = ?',
                (json.dumps(value, ensure_ascii=False), key),
            ).rowcount
            if changed != 1:
                raise RuntimeError('Cambio inesperado en la configuracion; se revierte la transaccion.')
    print('Ajustes globales de chat reparados. Usuarios, conversaciones y ajustes particulares conservados.')
    print('Copia privada: ' + str(backup_path))
except sqlite3.Error:
    raise SystemExit('No se pudo leer o actualizar la base SQLite esperada. No se modifica una base con otro esquema.')
finally:
    if connection is not None:
        connection.close()
'@

    # Attempt to bring WebUI back even if stop partially succeeds or repair fails.
    $restartWebUI = $true
    Invoke-LocalAICompose -Arguments @('stop', 'open-webui')
    Invoke-LocalAICompose -Arguments @(
        'run', '--rm', '--no-deps', '--entrypoint', 'python',
        'open-webui', '-c', $repairCode
    )
}
catch { $repairError = $_.Exception.Message }
finally {
    if ($restartWebUI) {
        try {
            Invoke-LocalAICompose -Arguments @(
                'up', '-d', '--no-deps', '--wait', '--wait-timeout', '600', 'open-webui'
            )
        }
        catch { $restartError = $_.Exception.Message }
    }
}

if ($repairError -or $restartError) {
    if ($repairError) { [Console]::Error.WriteLine(('ERROR al reparar: ' + $repairError)) }
    if ($restartError) { [Console]::Error.WriteLine(('ERROR al reiniciar WebUI: ' + $restartError)) }
    exit 1
}

Write-Host 'Open WebUI esta listo. Abre un chat nuevo para probar los nuevos ajustes.'
Write-Host 'Los ajustes explicitos de un modelo o chat pueden prevalecer sobre estos valores globales.'
