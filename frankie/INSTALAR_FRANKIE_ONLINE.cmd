@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"
title FRANKIE ONLINE - INSTALADOR
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$self='%~f0'; $raw=[IO.File]::ReadAllText($self); $m='###POWERSHELL###'; $i=$raw.IndexOf($m); if($i -lt 0){throw 'Payload PowerShell nao encontrado.'}; $ps=$raw.Substring($i+$m.Length); Invoke-Expression $ps"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo [ERRO] Instalacao encerrada com codigo %RC%.
pause
exit /b %RC%
###POWERSHELL###
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ReleaseBase = 'https://github.com/senha00998734-byte/fcm26-patch-fix/releases/download/frankie-v1'
$Docs = [Environment]::GetFolderPath('MyDocuments')
$Home = Join-Path $Docs 'FRANKIE_FC26'
$ModsDir = Join-Path $Home 'Mods'
$CacheDir = Join-Path $env:LOCALAPPDATA 'FRANKIE_FC26\Cache'
$LogDir = Join-Path $Home 'Logs'
foreach($d in @($Home,$ModsDir,$CacheDir,$LogDir)){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
$Log = Join-Path $LogDir ('install_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

function Info([string]$m){ Write-Host "[FRANKIE] $m" -ForegroundColor Cyan; Add-Content -LiteralPath $Log -Value "[INFO] $m" }
function Ok([string]$m){ Write-Host "[OK] $m" -ForegroundColor Green; Add-Content -LiteralPath $Log -Value "[OK] $m" }
function Warn([string]$m){ Write-Host "[AVISO] $m" -ForegroundColor Yellow; Add-Content -LiteralPath $Log -Value "[AVISO] $m" }

function Download-File([string]$Url,[string]$Dest){
  $name = Split-Path -Leaf $Dest
  Info "Baixando $name"
  if(Get-Command curl.exe -ErrorAction SilentlyContinue){
    & curl.exe -L --fail --retry 5 --retry-delay 3 --continue-at - --output $Dest $Url
    if($LASTEXITCODE -ne 0){ throw "Falha no download de $name (curl $LASTEXITCODE)." }
  } elseif(Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue){
    Start-BitsTransfer -Source $Url -Destination $Dest -DisplayName "FRANKIE $name"
  } else {
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -TimeoutSec 3600
  }
}

function Verify([string]$Path,[Int64]$Size,[string]$Sha){
  if(!(Test-Path -LiteralPath $Path)){ return $false }
  $fi = Get-Item -LiteralPath $Path
  if($fi.Length -ne $Size){ Warn "Tamanho incorreto em $($fi.Name): $($fi.Length), esperado $Size"; return $false }
  Info "Verificando SHA-256 de $($fi.Name)..."
  $h = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  if($h -ne $Sha.ToLowerInvariant()){ Warn "SHA-256 diferente em $($fi.Name)."; return $false }
  Ok "$($fi.Name) verificado."
  return $true
}

function Download-Verified([string]$Asset,[string]$Dest,[Int64]$Size,[string]$Sha){
  if(Verify $Dest $Size $Sha){ return }
  if(Test-Path -LiteralPath $Dest){ Remove-Item -LiteralPath $Dest -Force }
  Download-File ($ReleaseBase + '/' + $Asset) $Dest
  if(!(Verify $Dest $Size $Sha)){ throw "Arquivo baixado falhou na verificacao: $Asset" }
}

function Join-Parts([string[]]$Names,[string]$Dest,[Int64]$Size,[string]$Sha){
  if(Verify $Dest $Size $Sha){ return }
  if(Test-Path -LiteralPath $Dest){ Remove-Item -LiteralPath $Dest -Force }
  Info "Montando $(Split-Path -Leaf $Dest)..."
  $out = [IO.File]::Open($Dest,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try {
    foreach($n in $Names){
      $p = Join-Path $CacheDir $n
      if(!(Test-Path -LiteralPath $p)){ throw "Parte ausente: $n" }
      $input = [IO.File]::OpenRead($p)
      try { $input.CopyTo($out,8MB) } finally { $input.Dispose() }
    }
  } finally { $out.Dispose() }
  if(!(Verify $Dest $Size $Sha)){ throw "Falha ao reconstruir $(Split-Path -Leaf $Dest)." }
  foreach($n in $Names){ Remove-Item -LiteralPath (Join-Path $CacheDir $n) -Force -ErrorAction SilentlyContinue }
}

try {
  Clear-Host
  Write-Host '=========================================================' -ForegroundColor DarkCyan
  Write-Host '          FRANKIE FCM + LTA - INSTALADOR ONLINE' -ForegroundColor Cyan
  Write-Host '=========================================================' -ForegroundColor DarkCyan
  Write-Host ''
  Info "Destino dos mods: $ModsDir"

  $driveRoot = [IO.Path]::GetPathRoot($ModsDir)
  $drive = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $driveRoot.TrimEnd('\\') }
  if($drive -and $drive.FreeSpace -lt 8GB){ throw 'Espaco livre insuficiente. Libere pelo menos 8 GB no disco de Documentos.' }

  $p1 = Join-Path $ModsDir '01 - BRFP 26 V3 Parte 1.fifamod'
  Download-Verified '01-BRFP-26-V3-Parte-1.fifamod' $p1 79677617 '7f5f8c6402550c2eb57cf0aecb67dd02a5eb501332e0654b91f1049d371cf175'

  $p2 = Join-Path $ModsDir '02 - BRFP 26 V3 Parte 2.fifamod'
  Download-Verified '02-BRFP-26-V3-Parte-2.fifamod' $p2 438151620 '3972564539703ddc15f276bcd8b6f794494e9257293309225701952164f6e967'

  $p3parts = 0..6 | ForEach-Object { '03-BRFP-Parte3.part' + $_.ToString('000') }
  $p3sizes = @(480000000,480000000,480000000,480000000,480000000,480000000,380867936)
  for($i=0;$i -lt $p3parts.Count;$i++){
    $dest = Join-Path $CacheDir $p3parts[$i]
    if(!(Test-Path -LiteralPath $dest) -or ((Get-Item $dest).Length -ne [Int64]$p3sizes[$i])){
      if(Test-Path $dest){ Remove-Item $dest -Force }
      Download-File ($ReleaseBase + '/' + $p3parts[$i]) $dest
      if((Get-Item $dest).Length -ne [Int64]$p3sizes[$i]){ throw "Tamanho incorreto em $($p3parts[$i])." }
    }
  }
  $p3 = Join-Path $ModsDir '03 - BRFP 26 V3 Parte 3.fifamod'
  Join-Parts $p3parts $p3 3260867936 'c9dd836bfc372698d9bac54dbcb74e533f1be73a6e2ce9d41ebfcc0590e6a349'

  $ovparts = 0..2 | ForEach-Object { '04-FCM-Faces-Overlay.part' + $_.ToString('000') }
  $ovsizes = @(480000000,480000000,452302823)
  for($i=0;$i -lt $ovparts.Count;$i++){
    $dest = Join-Path $CacheDir $ovparts[$i]
    if(!(Test-Path -LiteralPath $dest) -or ((Get-Item $dest).Length -ne [Int64]$ovsizes[$i])){
      if(Test-Path $dest){ Remove-Item $dest -Force }
      Download-File ($ReleaseBase + '/' + $ovparts[$i]) $dest
      if((Get-Item $dest).Length -ne [Int64]$ovsizes[$i]){ throw "Tamanho incorreto em $($ovparts[$i])." }
    }
  }
  $ov = Join-Path $ModsDir '04 - FRANKENSTEIN FCM Faces Overlay.fifamod'
  Join-Parts $ovparts $ov 1412302823 'f008ff8c0b334ed5db4b6664d1978bbb9f31ca2836af6a51b75e9bb647479496'

  @"
FRANKIE FCM + LTA - ORDEM NO FIFA MOD MANAGER
==============================================
1. 01 - BRFP 26 V3 Parte 1.fifamod
2. 02 - BRFP 26 V3 Parte 2.fifamod
3. 03 - BRFP 26 V3 Parte 3.fifamod
4. 04 - FRANKENSTEIN FCM Faces Overlay.fifamod  (MAIOR PRIORIDADE)

Pasta dos mods:
$ModsDir
"@ | Set-Content -LiteralPath (Join-Path $Home 'ORDEM_MOD_MANAGER.txt') -Encoding UTF8

  Ok 'FRANKIE baixado, montado e validado com sucesso.'
  Write-Host ''
  Write-Host 'Agora importe os 4 arquivos no FIFA Mod Manager na ordem acima.' -ForegroundColor White
  Write-Host 'Depois inicie o jogo pelo botao Launch do Mod Manager.' -ForegroundColor White

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\FIFA Mod Manager\FIFA Mod Manager.exe'),
    (Join-Path $env:USERPROFILE 'Downloads\FIFA Mod Manager\FIFA Mod Manager.exe'),
    (Join-Path $env:USERPROFILE 'Desktop\FIFA Mod Manager\FIFA Mod Manager.exe'),
    (Join-Path $env:ProgramFiles 'FIFA Mod Manager\FIFA Mod Manager.exe'),
    ($(if(${env:ProgramFiles(x86)}){ Join-Path ${env:ProgramFiles(x86)} 'FIFA Mod Manager\FIFA Mod Manager.exe' }else{$null}))
  ) | Where-Object { $_ }
  $mm = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  Start-Process explorer.exe $ModsDir
  if($mm){ Info "Abrindo FIFA Mod Manager..."; Start-Process -FilePath $mm }
  else { Warn 'FIFA Mod Manager nao foi encontrado automaticamente. A pasta dos mods foi aberta.' }
  exit 0
}
catch {
  Write-Host ''
  Write-Host ('[ERRO] ' + $_.Exception.Message) -ForegroundColor Red
  Add-Content -LiteralPath $Log -Value ('[ERRO] ' + $_.Exception.ToString())
  Write-Host ('Log: ' + $Log) -ForegroundColor Yellow
  exit 1
}
