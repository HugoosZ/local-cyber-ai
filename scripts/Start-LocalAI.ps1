[CmdletBinding()]
param([switch]$WithComparison, [switch]$OpenBrowser)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

try {
    New-LocalAIEnvironment
    $settings = Get-LocalAISettings
    Write-Host 'Comprobando Docker Desktop y Docker Compose...'
    Start-LocalAIDockerDesktop
    Assert-LocalAIDockerReady

    Write-Host 'Comprobando que el contenedor puede acceder a la GPU NVIDIA...'
    Invoke-LocalAICompose -Arguments @(
        'run', '--rm', '--no-deps', '--entrypoint', 'nvidia-smi', 'ollama',
        '--query-gpu=name,memory.total', '--format=csv,noheader'
    )

    Write-Host 'Iniciando Ollama y Open WebUI...'
    Invoke-LocalAICompose -Arguments @('up', '-d', '--wait', '--wait-timeout', '600')
    $modelList = Invoke-LocalAICompose -Arguments @('exec', '-T', 'ollama', 'ollama', 'list') -CaptureOutput
    if ($modelList -notmatch ('(?m)^' + [regex]::Escape($settings.PrimaryModel) + '\s')) {
        Write-Host ("Descargando el modelo principal: {0}" -f $settings.PrimaryModel)
        Invoke-LocalAICompose -Arguments @('exec', '-T', 'ollama', 'ollama', 'pull', $settings.PrimaryModel)
    }
    else {
        Write-Host ("Modelo principal ya instalado: {0}. Se reutiliza sin consultar el registro." -f $settings.PrimaryModel)
    }
    if ($WithComparison) {
        $modelList = Invoke-LocalAICompose -Arguments @('exec', '-T', 'ollama', 'ollama', 'list') -CaptureOutput
        if ($modelList -notmatch ('(?m)^' + [regex]::Escape($settings.ComparisonModel) + '\s')) {
            Write-Host ("Descargando el modelo de comparacion: {0}" -f $settings.ComparisonModel)
            Invoke-LocalAICompose -Arguments @('exec', '-T', 'ollama', 'ollama', 'pull', $settings.ComparisonModel)
        }
        else {
            Write-Host ("Modelo de comparacion ya instalado: {0}. Se reutiliza sin consultar el registro." -f $settings.ComparisonModel)
        }
    }

    Write-Host ''
    $localUrl = 'http://eiai.localhost:{0}' -f $settings.Port
    Write-Host ("Listo. Abre {0}" -f $localUrl)
    Write-Host 'La primera vez, crea tu cuenta de administrador.'
    Write-Host ("Selecciona {0} en el chat. Contexto configurado: {1} tokens." -f $settings.PrimaryModel, $settings.ContextLength)
    Write-Host 'Para comprobar una respuesta y el uso de GPU: .\scripts\Test-LocalAI.ps1 -Inference'
    if ($OpenBrowser) {
        try { Start-Process -FilePath $localUrl | Out-Null }
        catch { Write-Warning ('No se pudo abrir el navegador automaticamente. Abre ' + $localUrl) }
    }
}
catch {
    [Console]::Error.WriteLine(('ERROR: ' + $_.Exception.Message))
    exit 1
}
