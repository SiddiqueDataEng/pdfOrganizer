<#
OrganizePDFs.ps1
Enhanced version with support for PDF, ODF, EPUB and README creation
Usage:
  Right-click → Run with PowerShell, or:
  powershell -ExecutionPolicy Bypass -File .\OrganizePDFs.ps1 -Root "C:\Path\To\Root" -Extensions @("pdf","odt","ods","odp","epub")
If -Root not provided, script uses current directory.
#>

param(
    [string]$Root = (Get-Location).Path,
    [int]$MaxNameLength = 50,
    [string[]]$Extensions = @("pdf", "odt", "ods", "odp", "epub"),
    [switch]$CreateReadme = $true
)

$log = Join-Path $Root "OrganizeFiles.log"
"=== Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $log -Encoding utf8 -Append

# Create a manifest of organized files for README
$organizedFiles = @{}

# Build include patterns for Get-ChildItem
$includePatterns = $Extensions | ForEach-Object { "*.$_" }

Write-Host "Searching for files with extensions: $($Extensions -join ', ')" -ForegroundColor Cyan

# Get all files recursively with specified extensions
Get-ChildItem -Path $Root -Recurse -Include $includePatterns -File -ErrorAction SilentlyContinue |
ForEach-Object {
    try {
        $file = $_
        $filename = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $parentFolderName = $file.Directory.Name

        # Skip if file is already in a folder with its name
        if ($parentFolderName -ieq $filename) {
            $msg = "SKIP (already organized): $($file.FullName)"
            $msg | Out-File -FilePath $log -Append -Encoding utf8
            Write-Host $msg -ForegroundColor Yellow
            
            # Add to manifest for README
            $folderKey = $file.Directory.FullName
            if (-not $organizedFiles.ContainsKey($folderKey)) {
                $organizedFiles[$folderKey] = @()
            }
            $organizedFiles[$folderKey] += $file.Name
            return
        }

        # Truncate folder name if needed
        if ($filename.Length -gt $MaxNameLength) {
            $folderName = $filename.Substring(0, $MaxNameLength)
            $msg = "Truncated folder name from $($filename.Length) to $MaxNameLength chars"
            $msg | Out-File -FilePath $log -Append -Encoding utf8
        } else {
            $folderName = $filename
        }

        $targetFolder = Join-Path $file.Directory.FullName $folderName

        # Create folder if it doesn't exist
        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder | Out-Null
            "Created folder: $targetFolder" | Out-File -FilePath $log -Append -Encoding utf8
            Write-Host "Created folder: $targetFolder" -ForegroundColor Green
        }

        $targetPath = Join-Path $targetFolder $file.Name

        # Handle filename collisions
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
            Write-Host $msg -ForegroundColor Yellow
        }

        # Move the file
        Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force
        $msg = "MOVED: $($file.Name) -> $([IO.Path]::GetFileName($targetFolder))"
        $msg | Out-File -FilePath $log -Append -Encoding utf8
        Write-Host $msg -ForegroundColor Green
        
        # Add to manifest for README
        if ($CreateReadme) {
            if (-not $organizedFiles.ContainsKey($targetFolder)) {
                $organizedFiles[$targetFolder] = @()
            }
            $organizedFiles[$targetFolder] += @{
                Name = [IO.Path]::GetFileName($targetPath)
                OriginalPath = $file.FullName
                Extension = $file.Extension
            }
        }
        
    } catch {
        $err = "ERROR processing $($file.FullName): $($_.Exception.Message)"
        $err | Out-File -FilePath $log -Append -Encoding utf8
        Write-Warning $err
    }
}

# Create README.md files
if ($CreateReadme) {
    Write-Host "`nCreating README.md files..." -ForegroundColor Cyan
    
    foreach ($folder in $organizedFiles.Keys) {
        try {
            $readmePath = Join-Path $folder "README.md"
            
            # Skip if README already exists
            if (Test-Path -LiteralPath $readmePath) {
                Write-Host "README already exists in $folder" -ForegroundColor Yellow
                continue
            }
            
            $folderName = Split-Path $folder -Leaf
            $parentPath = Split-Path $folder -Parent
            $relativePath = if ($parentPath -eq $Root) { "." } else { $parentPath.Replace($Root, "").TrimStart("\") }
            
            $readmeContent = @"
# $folderName

**Created:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Parent Directory:** [$relativePath]($relativePath)

## Files in this folder

| Filename | Type | Original Location |
|----------|------|-------------------|
"@

            foreach ($file in $organizedFiles[$folder]) {
                if ($file -is [hashtable]) {
                    $fileType = switch -Wildcard ($file.Extension) {
                        ".pdf"   { "📄 PDF Document" }
                        ".odt"   { "📝 ODT Text Document" }
                        ".ods"   { "📊 ODS Spreadsheet" }
                        ".odp"   { "📽️ ODP Presentation" }
                        ".epub"  { "📚 EPUB E-book" }
                        default  { "📁 File" }
                    }
                    $originalDir = Split-Path $file.OriginalPath -Parent
                    $relativeOriginal = if ($originalDir -eq $Root) { "." } else { $originalDir.Replace($Root, "").TrimStart("\") }
                    $readmeContent += "`n| $($file.Name) | $fileType | $relativeOriginal |"
                }
            }

            $readmeContent += @"

## Summary
- **Total files:** $($organizedFiles[$folder].Count)
- **Organized by:** OrganizeFiles.ps1
- **Log file:** [OrganizeFiles.log](../OrganizeFiles.log)

---
*This README was automatically generated.*
"@

            $readmeContent | Out-File -FilePath $readmePath -Encoding utf8
            Write-Host "Created README.md in $folder" -ForegroundColor Green
            "Created README: $readmePath" | Out-File -FilePath $log -Append -Encoding utf8
            
        } catch {
            $err = "ERROR creating README in $folder': $($_.Exception.Message)"
            $err | Out-File -FilePath $log -Append -Encoding utf8
            Write-Warning $err
        }
    }
}

# Summary report
$totalFiles = ($organizedFiles.Values | ForEach-Object { $_.Count }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$totalFolders = $organizedFiles.Keys.Count

$summary = @"

=== Summary ===
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Root directory: $Root
File types processed: $($Extensions -join ', ')
Total files organized: $totalFiles
Total folders created/updated: $totalFolders
README.md files created: $(if($CreateReadme){$totalFolders}else{0})
Log file: $log
"@

$summary | Out-File -FilePath $log -Append -Encoding utf8
Write-Host $summary -ForegroundColor Cyan
Write-Host "`nFinished. Log: $log" -ForegroundColor White