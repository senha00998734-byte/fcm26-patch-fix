$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

function Info([string]$Text,[string]$Title='FCM26 TU 1.6.6 COMPAT') {
  [System.Windows.Forms.MessageBox]::Show($Text,$Title,[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}
function Warn([string]$Text,[string]$Title='FCM26 TU 1.6.6 COMPAT') {
  [System.Windows.Forms.MessageBox]::Show($Text,$Title,[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
}
function PickFolder([string]$Description) {
  $d = New-Object System.Windows.Forms.FolderBrowserDialog
  $d.Description = $Description
  if ($d.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return $d.SelectedPath
}
function Get-FifaModHeader([string]$Path) {
  $fs = [System.IO.File]::OpenRead($Path)
  try {
    $br = New-Object System.IO.BinaryReader($fs)
    $magic = $br.ReadUInt64()
    $fmt = $br.ReadUInt32()
    $validMagic = ($magic -eq 72155812747760198) -or ($magic -eq 5498700893333637446)
    return [pscustomobject]@{ Path=$Path; Magic=$magic; FormatVersion=$fmt; ValidMagic=$validMagic; Size=(Get-Item $Path).Length }
  } finally { $fs.Dispose() }
}
function Backup-Move([string]$Path,[string]$Stamp) {
  if (Test-Path -LiteralPath $Path) {
    $dst = "$Path.BACKUP_$Stamp"
    Move-Item -LiteralPath $Path -Destination $dst -Force
    return $dst
  }
  return $null
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$report = New-Object System.Collections.Generic.List[string]
$report.Add('FCM26 TU 1.6.6 COMPAT - DIAGNOSTICO')
$report.Add(('Data: ' + (Get-Date)))
$report.Add('')

$choice = [System.Windows.Forms.MessageBox]::Show(
  "SIM = tentar o FCM V1 original com limpeza completa.`n`nNÃO = preparar o modo compatível LTA + conteúdo FCM que você já possui.`n`nCANCELAR = sair.",
  'Escolha o modo',
  [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
  [System.Windows.Forms.MessageBoxIcon]::Question)
if ($choice -eq [System.Windows.Forms.DialogResult]::Cancel) { exit 0 }

$game = PickFolder 'Selecione a pasta raiz do EA SPORTS FC 26 (onde fica FC26.exe)'
if (-not $game) { exit 0 }
if (-not (Test-Path (Join-Path $game 'FC26.exe'))) {
  Warn 'FC26.exe não foi encontrado. Execute novamente e selecione a pasta raiz correta do jogo.'
  exit 2
}

# Fecha processos antes de mexer em cache.
@('FC26','FIFA Mod Manager','FIFAModManager','FCM Mod Launcher') | ForEach-Object {
  Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Faz backup em vez de apagar definitivamente.
$report.Add('BACKUPS/CACHE')
foreach ($p in @((Join-Path $game 'FIFAModData'),(Join-Path $game 'ModData'),(Join-Path $env:LOCALAPPDATA 'EA SPORTS FC 26'))) {
  try {
    $b = Backup-Move $p $stamp
    if ($b) { $report.Add("Backup: $b") }
  } catch {
    $report.Add("Falha ao mover: $p :: $($_.Exception.Message)")
  }
}
$report.Add('')

if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
  $src = PickFolder 'Selecione a pasta onde estão os arquivos do FCM 26 V1 (.fifamod)'
  if (-not $src) { exit 0 }
  $mods = Get-ChildItem -LiteralPath $src -Filter '*.fifamod' -File -Recurse -ErrorAction SilentlyContinue
  if (-not $mods) {
    Warn 'Não encontrei nenhum .fifamod nessa pasta.'
    exit 3
  }

  $report.Add('ARQUIVOS FCM ENCONTRADOS')
  foreach ($m in $mods) {
    try {
      $h = Get-FifaModHeader $m.FullName
      $ok = if ($h.ValidMagic -and $h.FormatVersion -ge 4 -and $h.FormatVersion -le 29) {'OK'} else {'SUSPEITO'}
      $report.Add("[$ok] $($m.Name) | bytes=$($h.Size) | fifamod-format=$($h.FormatVersion) | magic=$($h.Magic)")
    } catch {
      $report.Add("[ERRO] $($m.Name) :: $($_.Exception.Message)")
    }
  }

  $fix = $mods | Where-Object { $_.Name -match '(?i)fix' } | Select-Object -First 1
  $p1  = $mods | Where-Object { $_.Name -match '(?i)(parte|part)[ _.-]*1' -and $_.Name -notmatch '(?i)fix' } | Select-Object -First 1
  $p2  = $mods | Where-Object { $_.Name -match '(?i)(parte|part)[ _.-]*2' -and $_.Name -notmatch '(?i)fix' } | Select-Object -First 1

  $order = New-Object System.Collections.Generic.List[string]
  $order.Add('FCM26 - ORDEM PARA TESTE NO TU 1.6.6')
  $order.Add('1. Patch FCM 26 Parte 1')
  $order.Add('2. Patch FCM 26 Parte 2')
  $order.Add('3. Patch FCM 26 FIX  <-- maior prioridade / por ultimo')
  $order.Add('')
  $order.Add('Depois use Delete FIFAMODDATA and launch.')
  $order.Add('Nao use LTA/Frankie neste primeiro teste.')
  $orderPath = Join-Path $src 'FCM26_TU166_ORDEM.txt'
  $order | Set-Content -LiteralPath $orderPath -Encoding UTF8

  $report.Add('')
  $report.Add('DETECCAO')
  $report.Add(('Parte 1: ' + $(if($p1){$p1.FullName}else{'NAO IDENTIFICADA'})))
  $report.Add(('Parte 2: ' + $(if($p2){$p2.FullName}else{'NAO IDENTIFICADA'})))
  $report.Add(('FIX: ' + $(if($fix){$fix.FullName}else{'NAO IDENTIFICADO'})))

  $launcher = @(
    (Join-Path $src 'FCM Mod Launcher.exe'),
    (Join-Path $game 'FCM Mod Launcher.exe'),
    (Join-Path $PSScriptRoot 'FCM Mod Launcher.exe')
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  $reportPath = Join-Path $src 'FCM26_TU166_DIAGNOSTICO.txt'
  $report | Set-Content -LiteralPath $reportPath -Encoding UTF8

  if ($launcher) {
    Info "Preparação concluída.`n`nFoi criado:`n$orderPath`n$reportPath`n`nVou abrir o FCM Mod Launcher como administrador."
    Start-Process -FilePath $launcher -Verb RunAs
  } else {
    Info "Preparação concluída.`n`nFoi criado:`n$orderPath`n$reportPath`n`nAbra o seu FCM Mod Launcher/FIFA Mod Manager como administrador e siga a ordem do TXT."
  }
}
else {
  $src = PickFolder 'Selecione a pasta onde estão os mods LTA/Frankie que já funcionam'
  if (-not $src) { exit 0 }
  $mods = Get-ChildItem -LiteralPath $src -Filter '*.fifamod' -File -Recurse -ErrorAction SilentlyContinue
  $wanted = @(
    $mods | Where-Object { $_.Name -match '(?i)(BRFP|LTA).*(Parte|Part).*1' } | Select-Object -First 1,
    $mods | Where-Object { $_.Name -match '(?i)(BRFP|LTA).*(Parte|Part).*2' } | Select-Object -First 1,
    $mods | Where-Object { $_.Name -match '(?i)(BRFP|LTA).*(Parte|Part).*3' } | Select-Object -First 1,
    $mods | Where-Object { $_.Name -match '(?i)(FCM.*Faces|Faces.*Overlay|FRANKENSTEIN.*Faces)' } | Select-Object -First 1
  ) | Where-Object { $_ }

  $dest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'FCM26_TU166_COMPAT\Mods'
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  foreach ($m in $wanted) { Copy-Item -LiteralPath $m.FullName -Destination $dest -Force }

  $order = @(
    'FCM26 TU 1.6.6 - MODO COMPAT LTA + FCM',
    '1. BRFP/LTA Parte 1',
    '2. BRFP/LTA Parte 2',
    '3. BRFP/LTA Parte 3',
    '4. FCM Faces Overlay / FRANKENSTEIN Faces Overlay',
    '',
    'Nao coloque o FIX antigo neste modo. Primeiro teste a base funcionando.',
    'Depois use Delete FIFAMODDATA and launch.'
  )
  $orderPath = Join-Path $dest 'ORDEM_MOD_MANAGER.txt'
  $order | Set-Content -LiteralPath $orderPath -Encoding UTF8
  $report.Add("Modo fallback preparado em: $dest")
  $report.Add("Mods copiados: $($wanted.Count)")
  $reportPath = Join-Path $dest 'DIAGNOSTICO.txt'
  $report | Set-Content -LiteralPath $reportPath -Encoding UTF8
  Info "Modo compat preparado em:`n$dest`n`nImporte os .fifamod dessa pasta no Mod Manager na ordem do TXT."
  Start-Process explorer.exe $dest
}
