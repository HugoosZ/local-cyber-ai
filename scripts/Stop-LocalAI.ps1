[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

try {
    New-LocalAIEnvironment
    $null = Get-LocalAISettings
    Write-Host 'Deteniendo los servicios y conservando modelos, usuarios y conversaciones...'
    Invoke-LocalAICompose -Arguments @('stop')
    Write-Host 'Servicios detenidos. Ejecuta Start-LocalAI.ps1 para iniciarlos de nuevo.'
}
catch {
    [Console]::Error.WriteLine(('ERROR: ' + $_.Exception.Message))
    exit 1
}
