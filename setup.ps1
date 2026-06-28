# LiveReins co-op partner installer. Finds R.E.P.O, installs BepInEx + ScalerCore if
# missing, pulls the host's latest LiveReins mods, then launches the game.
# Pass -RepoPath "C:\...\REPO" (or set LIVEREINS_REPO) to FORCE the folder — use the one
# Steam shows under "Browse local files", since a hand-moved game won't be auto-found.
param([string]$RepoPath = $env:LIVEREINS_REPO)
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

Write-Host "=== LiveReins co-op mods installer ===" -ForegroundColor Cyan
# Explicit -RepoPath wins (for hand-moved installs Steam launches from a different folder
# than where the game files sit). Then auto-find. Then ask.
if ($RepoPath -and (Test-Path (Join-Path $RepoPath "REPO.exe"))) { $REPO = $RepoPath; Write-Host "Using forced path." -ForegroundColor Cyan }
else { $REPO = Find-Repo }
if (-not $REPO) {
  Write-Host "Couldn't auto-find R.E.P.O." -ForegroundColor Yellow
  $REPO = Read-Host "Paste your R.E.P.O folder (the one with REPO.exe — use Steam > Browse local files)"
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

# --- Migrate off the OLD name (Puppeteer -> LiveReins) ---
# Before the rename the mod installed as PuppeteerMod. If BOTH load they fight over the
# command-server port 17385 (the second one errors out and commands stop) — so an existing
# install would keep showing "PuppeteerMod". Drop the old folder, any flat DLL, and the old
# BepInEx config so only LiveReins remains. Safe no-op when none of them are present.
Write-Host "Removing the old Puppeteer mod if present..." -ForegroundColor Cyan
Remove-Item (Join-Path $plugins "PuppeteerMod") -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $plugins -Recurse -Filter "PuppeteerMod.dll" -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
Remove-Item (Join-Path $REPO "BepInEx\config\com.jmike.puppeteer.cfg") -Force -ErrorAction SilentlyContinue

# --- LiveReins mods (always pull the host's latest) ---
Write-Host "Updating LiveReins mods..." -ForegroundColor Cyan
$jobs = @(
  @{ u = "$RAW/LiveReinsMod/LiveReinsMod.dll";       f = (Join-Path $plugins "LiveReinsMod\LiveReinsMod.dll") },
  @{ u = "$RAW/PlayableMonsters/PlayableMonsters.dll"; f = (Join-Path $plugins "PlayableMonsters\PlayableMonsters.dll") }
)
foreach ($j in $jobs) {
  New-Item -ItemType Directory -Force (Split-Path $j.f) | Out-Null
  Invoke-WebRequest $j.u -OutFile $j.f -UseBasicParsing
  Write-Host "  $([System.IO.Path]::GetFileName($j.f))" -ForegroundColor Green
}

# --- Sound pack (host's custom sounds so play_sound works on your machine) ---
# The mod reads sounds from the game's audio cache; pull the host's shared pack into it.
$audioCache = Join-Path $env:USERPROFILE "AppData\LocalLow\semiwork\Repo\Cache\Audio"
try {
  $sm = Invoke-WebRequest "$RAW/sounds-manifest.json" -UseBasicParsing -ErrorAction Stop
  $sounds = ($sm.Content | ConvertFrom-Json).sounds
  if ($sounds -and $sounds.Count -gt 0) {
    Write-Host "Pulling $($sounds.Count) shared sound(s)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force $audioCache | Out-Null
    foreach ($s in $sounds) {
      try { Invoke-WebRequest "$RAW/sounds/$([uri]::EscapeDataString($s))" -OutFile (Join-Path $audioCache $s) -UseBasicParsing -ErrorAction Stop } catch {}
    }
    Write-Host "  sounds synced." -ForegroundColor Green
  }
} catch { Write-Host "  (no shared sound pack yet)" -ForegroundColor DarkGray }

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
