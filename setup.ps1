# Puppeteer co-op partner installer. Finds R.E.P.O, installs BepInEx + ScalerCore if
# missing, pulls the host's latest Puppeteer mods, then launches the game.
$ErrorActionPreference = "Stop"
$RAW   = "https://raw.githubusercontent.com/itsJmikee/itsjmikee-mods/main/repo"
$APPID = "3241660"   # R.E.P.O Steam app id

function Find-Repo {
  $cands = New-Object System.Collections.Generic.List[string]
  $cands.Add("C:\Program Files (x86)\Steam\steamapps\common\REPO")
  $cands.Add("D:\Program Files (x86)\Steam\steamapps\common\REPO")
  $cands.Add("C:\Program Files\Steam\steamapps\common\REPO")
  $vdf = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
  if (Test-Path $vdf) {
    foreach ($line in Get-Content $vdf) {
      if ($line -match '"path"\s*"([^"]+)"') {
        $p = $matches[1] -replace '\\\\', '\'
        $cands.Add((Join-Path $p "steamapps\common\REPO"))
      }
    }
  }
  foreach ($c in $cands) { if (Test-Path (Join-Path $c "REPO.exe")) { return $c } }
  return $null
}

Write-Host "=== Puppeteer co-op mods installer ===" -ForegroundColor Cyan
$REPO = Find-Repo
if (-not $REPO) {
  Write-Host "Couldn't auto-find R.E.P.O." -ForegroundColor Yellow
  $REPO = Read-Host "Paste your R.E.P.O folder (the one with REPO.exe)"
}
if (-not (Test-Path (Join-Path $REPO "REPO.exe"))) { Write-Host "That folder has no REPO.exe. Aborting." -ForegroundColor Red; exit 1 }
Write-Host "R.E.P.O: $REPO"
$plugins = Join-Path $REPO "BepInEx\plugins"

# --- BepInEx (mod loader) ---
# Reinstall fresh if it's MISSING, INCOMPLETE (no preloader), or a Thunderstore Mod
# Manager left a half-managed setup (.thunderstoremm). That last case is the silent killer:
# all files look present but the Thunderstore doorstop fights a direct Steam launch, so the
# game never shows "[MODDED]" and no mods load. Wipe the loader + leftovers, install clean.
$tsLeftover = Test-Path (Join-Path $REPO ".thunderstoremm")
$bepComplete = (Test-Path (Join-Path $REPO "winhttp.dll")) -and (Test-Path (Join-Path $REPO "BepInEx\core\BepInEx.Preloader.dll"))
if ((-not $bepComplete) -or $tsLeftover) {
  if ($tsLeftover -or (Test-Path (Join-Path $REPO "winhttp.dll"))) {
    Write-Host "Cleaning old/partial BepInEx (Thunderstore leftover or incomplete)..." -ForegroundColor Yellow
    foreach ($x in @("BepInEx","winhttp.dll","doorstop_config.ini",".doorstop_version",".thunderstoremm","dotnet")) {
      Remove-Item (Join-Path $REPO $x) -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  Write-Host "Installing BepInEx 5..." -ForegroundColor Cyan
  $bz = Join-Path $env:TEMP "bepinex.zip"
  Invoke-WebRequest "https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.2/BepInEx_win_x64_5.4.23.2.zip" -OutFile $bz -UseBasicParsing
  Expand-Archive $bz -DestinationPath $REPO -Force
  Remove-Item $bz -Force
  New-Item -ItemType Directory -Force $plugins | Out-Null
} else { Write-Host "BepInEx already installed." }

# --- ScalerCore (dependency for scaling) ---
$hasScaler = Test-Path $plugins
if ($hasScaler) { $hasScaler = (Get-ChildItem $plugins -Recurse -Filter ScalerCore.dll -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0 }
if (-not $hasScaler) {
  Write-Host "Installing ScalerCore..." -ForegroundColor Cyan
  try {
    $api = Invoke-RestMethod "https://thunderstore.io/api/experimental/package/Vippy/ScalerCore/" -UseBasicParsing
    $sz = Join-Path $env:TEMP "scalercore.zip"
    Invoke-WebRequest $api.latest.download_url -OutFile $sz -UseBasicParsing
    $ext = Join-Path $env:TEMP "scalercore_ext"
    if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
    Expand-Archive $sz -DestinationPath $ext -Force
    $dll = Get-ChildItem $ext -Recurse -Filter ScalerCore.dll | Select-Object -First 1
    New-Item -ItemType Directory -Force (Join-Path $plugins "ScalerCore") | Out-Null
    Copy-Item $dll.FullName (Join-Path $plugins "ScalerCore\ScalerCore.dll") -Force
    Remove-Item $sz -Force; Remove-Item $ext -Recurse -Force
  } catch { Write-Host "ScalerCore auto-install failed ($($_.Exception.Message)). Install 'ScalerCore' from Thunderstore manually." -ForegroundColor Yellow }
} else { Write-Host "ScalerCore already installed." }

# --- Puppeteer mods (always pull the host's latest) ---
Write-Host "Updating Puppeteer mods..." -ForegroundColor Cyan
$jobs = @(
  @{ u = "$RAW/PuppeteerMod/PuppeteerMod.dll";       f = (Join-Path $plugins "PuppeteerMod\PuppeteerMod.dll") },
  @{ u = "$RAW/PlayableMonsters/PlayableMonsters.dll"; f = (Join-Path $plugins "PlayableMonsters\PlayableMonsters.dll") }
)
foreach ($j in $jobs) {
  New-Item -ItemType Directory -Force (Split-Path $j.f) | Out-Null
  Invoke-WebRequest $j.u -OutFile $j.f -UseBasicParsing
  Write-Host "  $([System.IO.Path]::GetFileName($j.f))" -ForegroundColor Green
}

# --- Unblock + console ---
# Windows tags downloaded DLLs with "mark of the web"; that can stop winhttp.dll loading as
# the proxy (BepInEx silently never starts). Unblock everything. Then enable the BepInEx
# console window (off by default) so you get the same debug console the host has.
Write-Host "Unblocking files + enabling console..." -ForegroundColor Cyan
Get-ChildItem $REPO -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
$cfg = Join-Path $REPO "BepInEx\config\BepInEx.cfg"
try {
  New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
  if (Test-Path $cfg) {
    $c = Get-Content $cfg -Raw
    if ($c -match '(?ms)\[Logging\.Console\].*?Enabled\s*=\s*\w+') { $c = $c -replace '(?ms)(\[Logging\.Console\][^\[]*?Enabled\s*=\s*)\w+', '${1}true' }
    else { $c += "`r`n[Logging.Console]`r`nEnabled = true`r`n" }
    Set-Content $cfg $c -Encoding UTF8
  } else {
    "[Logging.Console]`r`nEnabled = true`r`n" | Set-Content $cfg -Encoding UTF8
  }
} catch { Write-Host "(couldn't set console config: $($_.Exception.Message))" -ForegroundColor Yellow }

Write-Host "All set! Launching R.E.P.O..." -ForegroundColor Green
Start-Process "steam://rungameid/$APPID"
Start-Sleep -Seconds 2
