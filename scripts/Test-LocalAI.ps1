[CmdletBinding()]
param([switch]$Inference)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

try {
    $settings = Get-LocalAISettings
    Write-Host 'Comprobando Docker, configuracion y servicios...'
    Assert-LocalAIDockerReady
    Invoke-LocalAICompose -Arguments @('ps')

    $healthUrl = 'http://127.0.0.1:{0}/health' -f $settings.Port
    $health = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 15
    if ($health.StatusCode -ne 200) { throw 'Open WebUI no devolvio HTTP 200 en /health.' }
    Write-Host 'Open WebUI responde correctamente en /health.'

    # A working model alone does not detect WebUI injecting thousands of tool tokens.
    $chatDefaultsCode = @'
import json
import sqlite3

connection = sqlite3.connect('file:/app/backend/data/webui.db?mode=ro', uri=True)
try:
    row = connection.execute('SELECT value FROM config WHERE key = ?', ('models.default_metadata',)).fetchone()
    metadata = json.loads(row[0]) if row else {}
    if metadata.get('capabilities', {}).get('builtin_tools') is not False:
        raise SystemExit('Las herramientas internas siguen habilitadas por defecto. Ejecuta scripts/Repair-ChatDefaults.ps1 y abre un chat nuevo.')
    print('Chat de texto: herramientas internas desactivadas por defecto.')
finally:
    connection.close()
'@
    Invoke-LocalAICompose -Arguments @('exec', '-T', 'open-webui', 'python', '-c', $chatDefaultsCode)

    Write-Host 'Modelos disponibles en Ollama:'
    $modelList = Invoke-LocalAICompose -Arguments @('exec', '-T', 'ollama', 'ollama', 'list') -CaptureOutput
    Write-Host $modelList
    if ($modelList -notmatch ('(?m)^' + [regex]::Escape($settings.PrimaryModel) + '\s')) {
        throw 'El modelo principal no esta descargado. Ejecuta scripts/Start-LocalAI.ps1.'
    }

    if ($Inference) {
        Write-Host ("Probando una respuesta de {0}..." -f $settings.PrimaryModel)
        # Only single quotes inside this Python argument: Windows PowerShell 5.1 strips
        # embedded double quotes when forwarding native command arguments.
        $inferenceCode = @'
import json
import sys
import urllib.request

payload = {
    'model': sys.argv[1],
    'messages': [{'role': 'user', 'content': 'Responde solo con el numero: 2 + 2.'}],
    'stream': False,
    'think': False,
    'options': {'num_predict': 64, 'temperature': 0, 'num_ctx': int(sys.argv[2])},
}
request = urllib.request.Request(
    'http://ollama:11434/api/chat',
    data=json.dumps(payload).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST',
)
with urllib.request.urlopen(request, timeout=180) as response:
    result = json.load(response)
content = result.get('message', {}).get('content', '').strip()
if result.get('done') is not True:
    raise SystemExit('Ollama no confirmo que la respuesta este completa.')
if not content or ('4' not in content and 'cuatro' not in content.lower()):
    raise SystemExit('La prueba de 2 + 2 no produjo la respuesta esperada.')
print(content)
print('Tokens generados: {0}; segundos de generacion: {1:.2f}'.format(
    result.get('eval_count', 0), result.get('eval_duration', 0) / 1000000000,
))
'@
        Invoke-LocalAICompose -Arguments @(
            'exec', '-T', 'open-webui', 'python', '-c', $inferenceCode,
            $settings.PrimaryModel, [string]$settings.ContextLength
        )
        $loadedModels = Invoke-LocalAICompose -Arguments @('exec', '-T', 'ollama', 'ollama', 'ps') -CaptureOutput
        Write-Host $loadedModels
        $primaryRow = @($loadedModels -split '\r?\n' | Where-Object { $_ -match ('^' + [regex]::Escape($settings.PrimaryModel) + '\s') }) | Select-Object -First 1
        if ($null -eq $primaryRow -or $primaryRow -notmatch '100%\s+GPU') {
            throw 'La inferencia termino, pero Ollama no confirma 100% GPU para el modelo principal. Revisa VRAM, contexto y otras aplicaciones que usen la GPU.'
        }
        Write-Host 'Inferencia completada. Ollama confirma que el modelo principal esta 100% en GPU.'
    }
    else {
        Write-Host 'Comprobacion basica completada. Usa -Inference para comprobar generacion y carga en GPU.'
    }
}
catch {
    [Console]::Error.WriteLine(('ERROR: ' + $_.Exception.Message))
    exit 1
}
