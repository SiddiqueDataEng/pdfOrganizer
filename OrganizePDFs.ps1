<#
OrganizePDFs.ps1
Usage:
  Right-click → Run with PowerShell, or:
  powershell -ExecutionPolicy Bypass -File .\OrganizePDFs.ps1 -Root "C:\Path\To\Root"
If -Root not provided, script uses current directory.
#>

param(
    [string]$Root = (Get-Location).Path,
    [int]$MaxNameLength = 50
)

$log = Join-Path $Root "OrganizePDFs.log"
"=== Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $log -Encoding utf8 -Append

# Get all PDFs recursively (non-hidden)
Get-ChildItem -Path $Root -Recurse -Filter *.pdf -File -ErrorAction SilentlyContinue |
ForEach-Object {
    try {
        $file = $_
        $filename = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $parentFolderName = $file.Directory.Name

        if ($parentFolderName -ieq $filename) {
            $msg = "SKIP (already organized): $($file.FullName)"
            $msg | Out-File -FilePath $log -Append -Encoding utf8
            Write-Host $msg
            return
        }

        # Truncate folder name
        if ($filename.Length -gt $MaxNameLength) {
            $folderName = $filename.Substring(0, $MaxNameLength)
        } else {
            $folderName = $filename
        }

        $targetFolder = Join-Path $file.Directory.FullName $folderName

        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder | Out-Null
            "Created folder: $targetFolder" | Out-File -FilePath $log -Append -Encoding utf8
        }

        $targetPath = Join-Path $targetFolder $file.Name

        # If file with same name exists in target, add numeric suffix
        if (Test-Path -LiteralPath $targetPath) {
            $base = [IO.Path]::GetFileNameWithoutExtension($file.Name)
            $ext  = [IO.Path]::GetExtension($file.Name)
            $i = 1
            do {
                $newName = "{0}_{1}{2}" -f $base, $i, $ext
                $targetPath = Join-Path $targetFolder $newName
                $i++
            } while (Test-Path -LiteralPath $targetPath)
            $msg = "Collision: renaming to $newName"
            $msg | Out-File -FilePath $log -Append -Encoding utf8
            Write-Host $msg
        }

        Move-Item -LiteralPath $file.FullName -Destination $targetPath
        $msg = "MOVED: $($file.FullName) -> $targetPath"
        $msg | Out-File -FilePath $log -Append -Encoding utf8
        Write-Host $msg
    } catch {
        $err = "ERROR processing $($_.FullName): $($_.Exception.Message)"
        $err | Out-File -FilePath $log -Append -Encoding utf8
        Write-Warning $err
    }
}

"=== Done: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===`n" | Out-File -FilePath $log -Append -Encoding utf8
Write-Host "Finished. Log: $log"
