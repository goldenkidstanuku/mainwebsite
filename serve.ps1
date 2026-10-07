# Golden Kids School - Zero-Dependency Local Live Development Server with Auto-Reload
param (
    [int]$Port = 8000,
    [switch]$NoBrowser
)

$HostAddress = "http://localhost:$Port/"
$RootPath = (Get-Location).Path

$MimeTypes = @{
    ".html"  = "text/html; charset=utf-8"
    ".htm"   = "text/html; charset=utf-8"
    ".css"   = "text/css; charset=utf-8"
    ".js"    = "application/javascript; charset=utf-8"
    ".mjs"   = "application/javascript; charset=utf-8"
    ".json"  = "application/json; charset=utf-8"
    ".svg"   = "image/svg+xml"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".jfif"  = "image/jpeg"
    ".gif"   = "image/gif"
    ".webp"  = "image/webp"
    ".ico"   = "image/x-icon"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
}

function Get-ProjectTimestamp {
    $files = Get-ChildItem -Path $RootPath -Recurse -File -Exclude "*.log","*.tmp" -ErrorAction SilentlyContinue
    if ($files) {
        return ($files | Measure-Object -Property LastWriteTime -Maximum).Maximum.Ticks
    }
    return [DateTime]::UtcNow.Ticks
}

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add($HostAddress)

try {
    $Listener.Start()
} catch {
    # If initial port is in use, fallback to next available ports
    $fallbackPorts = @(8080, 8088, 3000, 5000)
    $started = $false
    foreach ($p in $fallbackPorts) {
        try {
            $Port = $p
            $HostAddress = "http://localhost:$Port/"
            $Listener = New-Object System.Net.HttpListener
            $Listener.Prefixes.Add($HostAddress)
            $Listener.Start()
            $started = $true
            break
        } catch {
            continue
        }
    }
    if (-not $started) {
        Write-Host "Error: Unable to bind to any HTTP port." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "   Golden Kids School - Local LIVE Web Server            " -ForegroundColor Cyan
Write-Host "   Status: Active & Watching for File Changes            " -ForegroundColor Green
Write-Host "   Live URL: $HostAddress                                 " -ForegroundColor Green
Write-Host "   Serving:  $RootPath                                    " -ForegroundColor Gray
Write-Host "   Features: Auto-Reload on Save, .jfif MIME, Poppins     " -ForegroundColor Magenta
Write-Host "   Press Ctrl+C in this console to stop the server        " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host ""

if (-not $NoBrowser) {
    Start-Process $HostAddress
}

try {
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response
        $UrlPath = $Request.Url.AbsolutePath

        try {
            # Live Server Heartbeat / Auto-Reload Endpoint
            if ($UrlPath -eq "/__livereload") {
                $ts = Get-ProjectTimestamp
                $json = "{`"timestamp`":$ts}"
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $Response.ContentType = "application/json; charset=utf-8"
                $Response.ContentLength64 = $bytes.Length
                $Response.StatusCode = 200
                $Response.AddHeader("Access-Control-Allow-Origin", "*")
                $Response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")
                $Response.OutputStream.Write($bytes, 0, $bytes.Length)
                $Response.OutputStream.Close()
                continue
            }

            if ($UrlPath -eq "/" -or [string]::IsNullOrWhiteSpace($UrlPath)) {
                $FilePath = Join-Path $RootPath "index.html"
            } else {
                $decoded = [System.Uri]::UnescapeDataString($UrlPath.TrimStart('/'))
                $cleanRel = $decoded.Replace('/', '\')
                $FilePath = Join-Path $RootPath $cleanRel
                # SPA Fallback: if not an existing file or directory, fallback to index.html
                if (-not (Test-Path $FilePath) -or (Test-Path $FilePath -PathType Container)) {
                    $FilePath = Join-Path $RootPath "index.html"
                }
            }

            if (Test-Path $FilePath -PathType Leaf) {
                $Ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
                $ContentType = $MimeTypes[$Ext]
                if (-not $ContentType) { $ContentType = "application/octet-stream" }

                $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
                $Response.ContentType = $ContentType
                $Response.ContentLength64 = $Bytes.Length
                $Response.StatusCode = 200
                $Response.AddHeader("Access-Control-Allow-Origin", "*")
                $Response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")
                $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            } else {
                $Response.StatusCode = 404
                $ErrorMsg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
                $Response.OutputStream.Write($ErrorMsg, 0, $ErrorMsg.Length)
            }
            $Response.OutputStream.Close()
        } catch {
            try { $Response.OutputStream.Close() } catch {}
        }
    }
} finally {
    $Listener.Stop()
    $Listener.Close()
    Write-Host "Server stopped." -ForegroundColor Red
}
