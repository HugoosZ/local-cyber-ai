[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

try {
    $profilePath = Join-Path $script:LocalAIProjectRoot 'model-profiles.json'
    $pythonPath = Join-Path $PSScriptRoot 'model_profiles.py'
    if (-not (Test-Path -LiteralPath $profilePath) -or -not (Test-Path -LiteralPath $pythonPath)) {
        throw 'Faltan los archivos de perfiles de EIAI.'
    }
    $null = Get-LocalAISettings
    Write-Host 'Comprobando modelos disponibles para aplicar perfiles...'
    Assert-LocalAIDockerReady
    $profiles = [IO.File]::ReadAllText($profilePath) | ConvertFrom-Json
    $installed = Invoke-LocalAICompose -Arguments @('exec', '-T', 'ollama', 'ollama', 'list') -CaptureOutput
    $availableProfiles = @($profiles | Where-Object { $installed -match ('(?m)^' + [regex]::Escape($_.id) + '\s') })
    if ($availableProfiles.Count -eq 0) {
        Write-Host 'No hay perfiles de EIAI para los modelos instalados. Se usan sus parametros predeterminados.'
        return
    }
    $profileJson = ConvertTo-Json -InputObject $availableProfiles -Depth 12 -Compress
    $profileEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($profileJson))
    Invoke-LocalAICompose -Arguments @('cp', $pythonPath, 'open-webui:/tmp/eiai_model_profiles.py')
    Invoke-LocalAICompose -Arguments @('exec', '-T', 'open-webui', 'python', '/tmp/eiai_model_profiles.py', $profileEncoded)
}
catch {
    [Console]::Error.WriteLine(('ERROR: ' + $_.Exception.Message))
    exit 1
}
