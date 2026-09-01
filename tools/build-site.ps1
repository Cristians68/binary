<#
.SYNOPSIS
  Assemble the deployable site into public/.

.DESCRIPTION
  The marketing site and the Flutter app are two different things served from
  one Firebase Hosting site, so they need assembling before deploy.

  Firebase Hosting serves a matching static file BEFORE it applies any rewrite.
  That means a build/web/index.html sitting at the root will always win for "/",
  and no rewrite can put the landing page there. The only reliable fix is to
  give them separate directories on disk:

      public/            <- site/ contents (landing page, legal, support)
      public/app/        <- the Flutter build

  The app is therefore built with --base-href /app/ so its own asset URLs point
  at the subdirectory it now lives in.

  public/ is generated and git-ignored. Never edit it; edit site/ or web/.

.EXAMPLE
  pwsh tools/build-site.ps1
  pwsh tools/build-site.ps1 -SkipApp     # marketing pages only, much faster
#>

[CmdletBinding()]
param(
  # Reuse whatever is already in build/web instead of rebuilding the Flutter
  # app. Useful when iterating on the marketing pages.
  [switch]$SkipApp
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$public = Join-Path $root 'public'
$appDir = Join-Path $public 'app'

# ── 1. Build the Flutter web app into build/web ────────────────────────────
if (-not $SkipApp) {
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    # The Flutter SDK is not on PATH on this machine; it lives at C:\flutter.
    $flutterBin = 'C:\flutter\bin'
    if (Test-Path $flutterBin) {
      $env:PATH = "$flutterBin;$env:PATH"
    } else {
      throw "flutter not found on PATH and $flutterBin does not exist."
    }
  }

  Write-Host '==> Building Flutter web app (base href /app/)' -ForegroundColor Cyan
  & flutter build web --release --base-href /app/
  if ($LASTEXITCODE -ne 0) { throw "flutter build web failed ($LASTEXITCODE)." }
}

$buildWeb = Join-Path $root 'build\web'
if (-not (Test-Path $buildWeb)) {
  throw "build/web does not exist. Run without -SkipApp first."
}

# Guard against deploying an app built for the wrong base href, which produces
# a blank page that only shows up after deploy.
$appIndex = Join-Path $buildWeb 'index.html'
if ((Get-Content $appIndex -Raw) -notmatch '<base href="/app/">') {
  throw "build/web/index.html is not built with --base-href /app/. Rerun without -SkipApp."
}

# ── 2. Reset public/ ───────────────────────────────────────────────────────
Write-Host '==> Assembling public/' -ForegroundColor Cyan
if (Test-Path $public) { Remove-Item $public -Recurse -Force }
New-Item -ItemType Directory -Path $public | Out-Null

# ── 3. Marketing site at the root ──────────────────────────────────────────
Copy-Item (Join-Path $root 'site\*') $public -Recurse -Force

# Shared assets live in web/ because the Flutter app needs them too.
Copy-Item (Join-Path $root 'web\favicon.png') $public -Force
Copy-Item (Join-Path $root 'web\icons') $public -Recurse -Force

# ── 4. Flutter app under /app ──────────────────────────────────────────────
New-Item -ItemType Directory -Path $appDir | Out-Null
Copy-Item (Join-Path $buildWeb '*') $appDir -Recurse -Force

# ── 5. Report ──────────────────────────────────────────────────────────────
$pages = Get-ChildItem $public -Filter *.html | Select-Object -ExpandProperty Name
$size = '{0:N1} MB' -f ((Get-ChildItem $public -Recurse -File |
  Measure-Object -Property Length -Sum).Sum / 1MB)

Write-Host ''
Write-Host "Assembled public/  ($size)" -ForegroundColor Green
Write-Host "  root pages : $($pages -join ', ')"
Write-Host "  app        : public/app/"
Write-Host ''
Write-Host 'Preview locally:  firebase emulators:start --only hosting'
Write-Host 'Deploy:           firebase deploy --only hosting'
