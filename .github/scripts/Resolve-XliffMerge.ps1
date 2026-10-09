Set-StrictMode -Version Latest

function Invoke-Git {
  param(
    [Parameter(Mandatory)] [string[]]$Arguments,
    [int[]]$AllowedExitCodes = @(0)
  )

  & git @Arguments | Out-Host
  if ($LASTEXITCODE -notin $AllowedExitCodes) {
    throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
  }
}

function Invoke-GitCapture {
  param([Parameter(Mandatory)] [string[]]$Arguments)

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = (Get-Command git -ErrorAction Stop).Source
  $startInfo.WorkingDirectory = (Get-Location).Path
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }

  $process = [System.Diagnostics.Process]::Start($startInfo)
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) {
    throw "git $($Arguments -join ' ') failed with exit code $($process.ExitCode): $stderr"
  }
  return $stdout
}

function Invoke-GitToFile {
  param(
    [Parameter(Mandatory)] [string[]]$Arguments,
    [Parameter(Mandatory)] [string]$Destination
  )

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = (Get-Command git -ErrorAction Stop).Source
  $startInfo.WorkingDirectory = (Get-Location).Path
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }

  $process = [System.Diagnostics.Process]::Start($startInfo)
  $file = [System.IO.File]::Create($Destination)
  try {
    $process.StandardOutput.BaseStream.CopyTo($file)
  } finally {
    $file.Dispose()
  }
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) {
    throw "git $($Arguments -join ' ') failed with exit code $($process.ExitCode): $stderr"
  }
}

function Test-Xml {
  param([Parameter(Mandatory)] [string]$LiteralPath)

  try {
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($LiteralPath, $settings)
    try {
      $document = [System.Xml.XmlDocument]::new()
      $document.XmlResolver = $null
      $document.Load($reader)
    } finally {
      $reader.Dispose()
    }

    return $document.DocumentElement.LocalName -eq 'xliff' -and
      $document.DocumentElement.GetAttribute('version') -eq '1.2'
  } catch {
    return $false
  }
}

function Get-UnmergedPaths {
  $output = Invoke-GitCapture -Arguments @('ls-files', '--unmerged', '-z')
  $paths = foreach ($entry in $output.Split("`0", [System.StringSplitOptions]::RemoveEmptyEntries)) {
    if ($entry -match '^\d+ [0-9a-f]+ [123]\t(?<path>.*)$') { $Matches.path }
  }
  return @($paths | Sort-Object -Unique)
}

function Test-XliffConflictStages {
  param([Parameter(Mandatory)] [string]$Path)

  if ([System.IO.Path]::GetExtension($Path) -notin @('.xlf', '.xliff')) { return $false }

  $entries = Invoke-GitCapture -Arguments @('ls-files', '--stage', '-z', '--', $Path)
  $stages = @{}
  foreach ($entry in $entries.Split("`0", [System.StringSplitOptions]::RemoveEmptyEntries)) {
    if ($entry -match '^(?<mode>\d+) (?<sha>[0-9a-f]+) (?<stage>[123])\t') {
      $stages[$Matches.stage] = $Matches.mode
    }
  }

  return @('1', '2', '3').Count -eq $stages.Count -and
    @($stages.Values | Where-Object { $_ -notmatch '^100' }).Count -eq 0
}

function Resolve-XliffUnionConflict {
  param([Parameter(Mandatory)] [string[]]$Paths)

  $ineligible = @($Paths | Where-Object { -not (Test-XliffConflictStages -Path $_) })
  if ($ineligible.Count -gt 0) {
    throw "Only regular XLIFF conflicts with stages 1, 2, and 3 can be resolved: $($ineligible -join ', ')"
  }

  $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("itb-xliff-" + [guid]::NewGuid().ToString('N'))
  [System.IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
  try {
    for ($index = 0; $index -lt $Paths.Count; $index++) {
      $path = $Paths[$index]
      $base = Join-Path $temporaryDirectory "$index-base"
      $ours = Join-Path $temporaryDirectory "$index-ours"
      $theirs = Join-Path $temporaryDirectory "$index-theirs"
      Invoke-GitToFile -Arguments @('show', ":1:$path") -Destination $base
      Invoke-GitToFile -Arguments @('show', ":2:$path") -Destination $ours
      Invoke-GitToFile -Arguments @('show', ":3:$path") -Destination $theirs

      Invoke-Git -Arguments @('merge-file', '--union', $ours, $base, $theirs)
      if (-not (Test-Xml -LiteralPath $ours)) {
        throw "Union result is not valid XLIFF 1.2 XML: $path"
      }

      $destination = Join-Path (Get-Location) $path
      [System.IO.File]::Copy($ours, $destination, $true)
      Invoke-Git -Arguments @('add', '--', $path)
    }
  } finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  }

  $remaining = @(Get-UnmergedPaths)
  if ($remaining.Count -gt 0) {
    throw "Unmerged paths remain after XLIFF union: $($remaining -join ', ')"
  }
}

function Merge-GitBranchesSequentially {
  param([Parameter(Mandatory)] [string[]]$Branches)

  foreach ($branch in $Branches) {
    & git merge --no-edit --no-ff -- $branch
    if ($LASTEXITCODE -eq 0) { continue }

    $conflictFiles = @(Get-UnmergedPaths)
    try {
      if ($conflictFiles.Count -eq 0) {
        throw "Merge failed without unmerged paths."
      }
      Resolve-XliffUnionConflict -Paths $conflictFiles
      Invoke-Git -Arguments @('commit', '--no-edit')
    } catch {
      $exception = [System.Exception]::new("Branch '$branch' could not be merged: $($_.Exception.Message)", $_.Exception)
      $exception.Data['ConflictBranch'] = $branch
      $exception.Data['ConflictFiles'] = $conflictFiles
      & git merge --abort 2>$null
      throw $exception
    }
  }
}