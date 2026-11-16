# 미리보기용 정적 파일 서버 (python이 없는 Windows PC용 — Windows PowerShell 5.1만 있으면 됨)
#   launch.json의 "portfolio-local-ps" 구성이 씀:  powershell -File .claude/serve.ps1 -Root . -Port 4600
#   읽기만 함. HEAD 요청(앱이 서버가 떴는지 확인할 때 씀)에는 본문 없이 머리만 돌려줌
param([string]$Root = '.', [int]$Port = 4600)
$ErrorActionPreference = 'Stop'
if ($env:PORT -match '^\d+$') { $Port = [int]$env:PORT }   # 미리보기 앱이 다른 포트를 정해 주면 그 포트로
$rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
$mime = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.mjs' = 'text/javascript; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.md' = 'text/markdown; charset=utf-8'
  '.tsv' = 'text/tab-separated-values; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.svg' = 'image/svg+xml'
  '.webp' = 'image/webp'; '.ico' = 'image/x-icon'; '.woff' = 'font/woff'; '.woff2' = 'font/woff2'
}
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $rootFull on http://localhost:$Port/"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($rel -eq '' -or $rel.EndsWith('/')) { $rel = $rel + 'index.html' }
    $full = [System.IO.Path]::GetFullPath((Join-Path $rootFull ($rel -replace '/', '\')))
    if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
      $res.StatusCode = 404
    } else {
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      $res.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' })
      $res.Headers.Add('Cache-Control', 'no-store')
      $bytes = [System.IO.File]::ReadAllBytes($full)
      $res.ContentLength64 = $bytes.Length
      if ($ctx.Request.HttpMethod -ne 'HEAD') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
    }
  } catch {
    Write-Host "error: $($ctx.Request.HttpMethod) $($ctx.Request.Url.AbsolutePath) - $_"
    try { $res.StatusCode = 500 } catch {}
  } finally {
    try { $res.Close() } catch {}
  }
}
