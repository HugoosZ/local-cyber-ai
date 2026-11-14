Set-StrictMode -Version 2.0

$script:LocalAIProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Get-LocalAIDockerPath {
    $command = Get-Command docker.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        $command = Get-Command docker -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($null -ne $command) { return $command.Source }

    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe'
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw 'No se encontro Docker. Instala Docker Desktop, activa WSL2 y abre Docker Desktop antes de continuar.'
}

function Test-LocalAIDockerEngine {
    param([Parameter(Mandatory = $true)][string]$DockerPath)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $null = & $DockerPath info --format '{{.OSType}}' 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    finally { $ErrorActionPreference = $previousPreference }
}

function Start-LocalAIDockerDesktop {
    $dockerPath = Get-LocalAIDockerPath
    if (Test-LocalAIDockerEngine -DockerPath $dockerPath) { return }

    $candidates = @()
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'
    }
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    }
    $desktopPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $desktopPath) {
        throw 'Docker no responde y no se encontro Docker Desktop. Abre Docker Desktop manualmente y vuelve a iniciar.'
    }

    Write-Host 'Iniciando Docker Desktop. Puede tardar un momento...'
    if (-not (Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $desktopPath -WindowStyle Hidden | Out-Null
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        if (Test-LocalAIDockerEngine -DockerPath $dockerPath) { return }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Docker Desktop no termino de arrancar en 120 segundos. Revisa su ventana (WSL2 o configuracion inicial) y vuelve a ejecutar el inicio.'
}

function New-LocalAIEnvironment {
    $environmentPath = Join-Path $script:LocalAIProjectRoot '.env'
    if (Test-Path -LiteralPath $environmentPath -PathType Leaf) { return }
    $examplePath = Join-Path $script:LocalAIProjectRoot '.env.example'
    if (-not (Test-Path -LiteralPath $examplePath -PathType Leaf)) {
        throw 'Falta .env.example en la raiz del proyecto.'
    }

    $template = [IO.File]::ReadAllText($examplePath)
    if ($template -notmatch '(?m)^WEBUI_SECRET_KEY=') {
        throw 'El ejemplo debe contener una linea WEBUI_SECRET_KEY=.'
    }
    $randomBytes = New-Object byte[] 32
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($randomBytes) }
    finally { $generator.Dispose() }
    $secret = [BitConverter]::ToString($randomBytes).Replace('-', '').ToLowerInvariant()
    $content = [regex]::Replace($template, '(?m)^WEBUI_SECRET_KEY=[^\r\n]*', ('WEBUI_SECRET_KEY=' + $secret))
    $encoding = New-Object Text.UTF8Encoding $false

    # CreateNew avoids overwriting an existing configuration, including two simultaneous starts.
    try {
        $stream = New-Object IO.FileStream($environmentPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    }
    catch [IO.IOException] {
        if (Test-Path -LiteralPath $environmentPath -PathType Leaf) { return }
        throw
    }
    try {
        $writer = New-Object IO.StreamWriter($stream, $encoding)
        try { $writer.Write($content) }
        finally { $writer.Dispose() }
    }
    finally { $stream.Dispose() }
    Write-Host 'Se creo .env con una clave aleatoria local. No compartas ese archivo.'
}

function Get-LocalAISettings {
    $environmentPath = Join-Path $script:LocalAIProjectRoot '.env'
    if (-not (Test-Path -LiteralPath $environmentPath -PathType Leaf)) {
        throw 'Falta .env. Ejecuta scripts/Start-LocalAI.ps1 para crearlo.'
    }
    $values = @{}
    foreach ($line in [IO.File]::ReadAllLines($environmentPath)) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $name = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value.StartsWith('"') -or $value.StartsWith("'")) {
                $quote = $value.Substring(0, 1)
                $closingQuote = $value.IndexOf($quote, 1)
                if ($closingQuote -lt 0) { throw "El valor de $name tiene comillas sin cerrar en .env." }
                $suffix = $value.Substring($closingQuote + 1).Trim()
                if ($suffix -and -not $suffix.StartsWith('#')) {
                    throw "El valor de $name contiene texto no valido en .env."
                }
                $value = $value.Substring(1, $closingQuote - 1)
            }
            else { $value = ([regex]::Replace($value, '\s+#.*$', '')).Trim() }
            $values[$name] = $value
        }
    }

    [int]$port = 0
    if (-not [int]::TryParse([string]$values['WEBUI_PORT'], [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
        throw 'WEBUI_PORT debe ser un entero entre 1 y 65535 en .env.'
    }
    [int]$contextLength = 0
    if (-not [int]::TryParse([string]$values['OLLAMA_CONTEXT_LENGTH'], [ref]$contextLength) -or $contextLength -lt 512) {
        throw 'OLLAMA_CONTEXT_LENGTH debe ser un entero de al menos 512 tokens en .env.'
    }
    foreach ($name in @('OLLAMA_NUM_PARALLEL', 'OLLAMA_MAX_LOADED_MODELS')) {
        [int]$number = 0
        if (-not [int]::TryParse([string]$values[$name], [ref]$number) -or $number -lt 1) {
            throw "$name debe ser un entero positivo en .env."
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$values['WEBUI_SECRET_KEY']) -or ([string]$values['WEBUI_SECRET_KEY']).Length -lt 32) {
        throw 'WEBUI_SECRET_KEY debe tener al menos 32 caracteres. Conserva la clave generada por el script.'
    }
    foreach ($name in @('PRIMARY_MODEL', 'COMPARISON_MODEL')) {
        if ([string]$values[$name] -notmatch '^[A-Za-z0-9][A-Za-z0-9._:/-]*$') {
            throw "$name debe contener un identificador de modelo Ollama valido en .env."
        }
    }

    # Return only non-secret configuration so routine inspection cannot print the secret key.
    return [pscustomobject]@{
        Port = $port
        ContextLength = $contextLength
        PrimaryModel = [string]$values['PRIMARY_MODEL']
        ComparisonModel = [string]$values['COMPARISON_MODEL']
    }
}

function Invoke-LocalAIDocker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$CaptureOutput
    )
    $dockerPath = Get-LocalAIDockerPath
    $previousPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 wraps native stderr as ErrorRecord, even on successful commands.
        # Judge native commands by LASTEXITCODE, never by the stderr stream or $?.
        $ErrorActionPreference = 'Continue'
        if ($CaptureOutput) {
            $lines = @(& $dockerPath @Arguments 2>&1)
        }
        else {
            & $dockerPath @Arguments 2>&1 | ForEach-Object { Write-Host $_.ToString() }
        }
        $nativeExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }

    if ($nativeExitCode -ne 0) {
        if ($CaptureOutput) { $lines | ForEach-Object { Write-Host $_.ToString() } }
        throw "Docker termino con codigo $nativeExitCode. Revisa el mensaje anterior y que Docker Desktop este en ejecucion."
    }
    if ($CaptureOutput) {
        return [string]::Join([Environment]::NewLine, @($lines | ForEach-Object { $_.ToString() }))
    }
}

function Invoke-LocalAICompose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$CaptureOutput
    )
    $composePath = Join-Path $script:LocalAIProjectRoot 'compose.yaml'
    if (-not (Test-Path -LiteralPath $composePath -PathType Leaf)) {
        throw 'Falta compose.yaml en la raiz del proyecto.'
    }
    $dockerArguments = @(
        'compose', '--project-name', 'local-cyber-ai',
        '--project-directory', $script:LocalAIProjectRoot,
        '--env-file', (Join-Path $script:LocalAIProjectRoot '.env'),
        '--file', $composePath
    ) + $Arguments
    Invoke-LocalAIDocker -Arguments $dockerArguments -CaptureOutput:$CaptureOutput
}

function Assert-LocalAIDockerReady {
    $null = Invoke-LocalAIDocker -Arguments @('compose', 'version') -CaptureOutput
    $osType = Invoke-LocalAIDocker -Arguments @('info', '--format', '{{.OSType}}') -CaptureOutput
    if ($osType.Trim() -ne 'linux') {
        throw 'Docker debe usar contenedores Linux. En Docker Desktop activa el backend WSL2 y cambia a Linux containers.'
    }
    $null = Invoke-LocalAICompose -Arguments @('config', '--quiet') -CaptureOutput
}
