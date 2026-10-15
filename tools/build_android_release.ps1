param([switch]$SplitPerAbi)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
Push-Location $projectPath
try {
 if (-not (Test-Path -LiteralPath 'android/key.properties')) { throw 'Configure android/key.properties com a keystore privada antes de gerar o APK de distribuição.' }
 flutter pub get
 if ($LASTEXITCODE -ne 0) { throw 'Falha nas dependências' }
 flutter analyze
 if ($LASTEXITCODE -ne 0) { throw 'Falha na análise' }
 flutter test
 if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes' }
 if ($SplitPerAbi) { flutter build apk --release --split-per-abi } else { flutter build apk --release }
 if ($LASTEXITCODE -ne 0) { throw 'Falha no build' }
} finally { Pop-Location }
