$ErrorActionPreference = 'Stop'

$sourcePath = Read-Host 'Enter the source folder path'
if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
	Write-Error 'The source folder does not exist.'
	exit 1
}
$sourcePath = (Resolve-Path -LiteralPath $sourcePath).Path.TrimEnd('\')

$usbDrives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 2')
if ($usbDrives.Count -eq 0) {
	Write-Error 'No USB drives were found.'
	exit 1
}
for ($i = 0; $i -lt $usbDrives.Count; $i++) {
	Write-Host "[$i] $($usbDrives[$i].DeviceID) $($usbDrives[$i].VolumeName)"
}
$choice = Read-Host 'Select the USB drive number'
if ($choice -notmatch '^\d+$' -or [int]$choice -ge $usbDrives.Count) {
	Write-Error 'Invalid selection.'
	exit 1
}

$destinationRoot = "$($usbDrives[[int]$choice].DeviceID)\USB-5GB-Copy"
if (Test-Path -LiteralPath $destinationRoot) {
	Write-Error "Destination already exists: $destinationRoot"
	exit 1
}

$limit = [int64](5 * 1GB)
$selectedFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$totalBytes = [int64]0
Get-ChildItem -LiteralPath $sourcePath -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
	if ($_.Length -le ($limit - $totalBytes)) {
		$selectedFiles.Add($_)
		$totalBytes += $_.Length
	}
}

if ($totalBytes -eq 0) {
	Write-Error 'No files fit within the 5 GB limit.'
	exit 1
}
Write-Host ("Copying {0:N2} GB in {1} files to {2}. Files are skipped if they would exceed 5 GB." -f ($totalBytes / 1GB), $selectedFiles.Count, $destinationRoot)
if ((Read-Host 'Continue? (Y/N)') -notmatch '^(?i:y)$') { exit 0 }

foreach ($file in $selectedFiles) {
	$relativePath = $file.FullName.Substring($sourcePath.Length).TrimStart('\')
	$targetPath = Join-Path $destinationRoot $relativePath
	New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
	Copy-Item -LiteralPath $file.FullName -Destination $targetPath
}
Write-Host ("Finished copying {0:N2} GB to {1}" -f ($totalBytes / 1GB), $destinationRoot)
