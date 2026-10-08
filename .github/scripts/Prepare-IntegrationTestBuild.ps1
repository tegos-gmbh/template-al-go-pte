param(
  [Parameter(Mandatory)] [string]$IntegrationBranch,
  [Parameter(Mandatory)] [string]$BranchesJson,
  [Parameter(Mandatory)] [string]$MetadataJson,
  [Parameter(Mandatory)] [string]$TestNumbersJson,
  [Parameter(Mandatory)] [string]$DefaultBranch,
  [Parameter(Mandatory)] [string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'Resolve-XliffMerge.ps1')

function Write-PreparationResult {
  param(
    [Parameter(Mandatory)] [bool]$Success,
    [Parameter(Mandatory)] [string]$Status,
    [string]$Message = '',
    [string]$ConflictBranch = '',
    [string[]]$ConflictFiles = @()
  )

  $result = [ordered]@{
    success        = $Success
    status         = $Status
    message        = $Message
    conflictBranch = $ConflictBranch
    conflictFiles  = @($ConflictFiles)
  }
  [System.IO.File]::WriteAllText(
    $ResultPath,
    ($result | ConvertTo-Json -Depth 10),
    [System.Text.UTF8Encoding]::new($false)
  )
}

function ConvertFrom-RequiredJsonArray {
  param(
    [Parameter(Mandatory)] [string]$Json,
    [Parameter(Mandatory)] [string]$Name
  )

  $parsed = $Json | ConvertFrom-Json -NoEnumerate
  if ($parsed -isnot [System.Array]) {
    throw "$Name must be a non-empty JSON array of strings."
  }
  $value = @($parsed)
  if ($value.Count -eq 0 -or @($value | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    throw "$Name must be a non-empty JSON array of strings."
  }
  return @($value)
}

function Get-NullDelimitedGitOutput {
  param([Parameter(Mandatory)] [string[]]$Arguments)

  $output = Invoke-GitCapture -Arguments $Arguments
  return @($output.Split("`0", [System.StringSplitOptions]::RemoveEmptyEntries))
}

function Test-RemoteBranchExists {
  param([Parameter(Mandatory)] [string]$Branch)

  & git ls-remote --exit-code --heads origin "refs/heads/$Branch" *> $null
  if ($LASTEXITCODE -eq 0) { return $true }
  if ($LASTEXITCODE -eq 2) { return $false }
  throw "Could not check whether remote branch '$Branch' exists."
}

function Set-TestAppBriefs {
  param([Parameter(Mandatory)] [int[]]$TestNumbers)

  $changedFiles = @(Get-NullDelimitedGitOutput -Arguments @('diff', '--name-only', '-z', "origin/$DefaultBranch...HEAD"))
  if ($changedFiles.Count -eq 0) { return @() }

  $appJsonPaths = @(Get-NullDelimitedGitOutput -Arguments @('ls-files', '-z', ':(glob)**/app.json', 'app.json') |
    Where-Object { $_ -notmatch '(^|/)(\.alpackages|\.snapshots|\.buildartifacts|_build)/' } |
    Sort-Object -Unique)
  $issueList = @($TestNumbers | Sort-Object -Unique | ForEach-Object { "#$_" }) -join ', '
  $brief = "TEST-BUILD – Test-App für $issueList – nicht produktiv einsetzen"
  if ($brief.Length -gt 250) { $brief = $brief.Substring(0, 250) }

  $markedApps = @()
  foreach ($path in $appJsonPaths) {
    $folder = [System.IO.Path]::GetDirectoryName($path).Replace('\', '/')
    $changed = if ([string]::IsNullOrEmpty($folder)) {
      $changedFiles.Count -gt 0
    } else {
      @($changedFiles | Where-Object { $_ -eq $path -or $_.StartsWith("$folder/", [System.StringComparison]::Ordinal) }).Count -gt 0
    }
    if (-not $changed) { continue }

    $fullPath = Join-Path (Get-Location) $path
    $original = [System.IO.File]::ReadAllText($fullPath)
    $app = $original | ConvertFrom-Json
    if ($app.PSObject.Properties.Name -contains 'brief') {
      $app.brief = $brief
    } else {
      $app | Add-Member -NotePropertyName brief -NotePropertyValue $brief
    }
    $newline = if ($original.EndsWith("`n")) { "`n" } else { '' }
    [System.IO.File]::WriteAllText(
      $fullPath,
      (($app | ConvertTo-Json -Depth 100) + $newline),
      [System.Text.UTF8Encoding]::new($false)
    )
    Invoke-Git -Arguments @('add', '--', $path)
    $markedApps += [ordered]@{ name = [string]$app.name; publisher = [string]$app.publisher }
  }
  return @($markedApps)
}

$currentConflictBranch = ''
$currentConflictFiles = @()
try {
  if ($IntegrationBranch -notmatch '^test-branch/itb-[0-9]+-[0-9]+$') {
    throw 'Invalid integration branch name.'
  }
  if ($DefaultBranch -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or $DefaultBranch.StartsWith('-')) {
    throw 'Invalid default branch name.'
  }
  Invoke-Git -Arguments @('check-ref-format', '--branch', $DefaultBranch)

  $branches = @(ConvertFrom-RequiredJsonArray -Json $BranchesJson -Name 'branches')
  if (@($branches | Sort-Object -Unique).Count -ne $branches.Count) {
    throw 'branches must already be deduplicated.'
  }
  foreach ($branch in $branches) {
    if ($branch.StartsWith('-')) { throw "Invalid branch name: $branch" }
    Invoke-Git -Arguments @('check-ref-format', '--branch', $branch)
  }

  $parsedTestNumbers = $TestNumbersJson | ConvertFrom-Json -NoEnumerate
  $testNumbers = @($parsedTestNumbers)
  if ($parsedTestNumbers -isnot [System.Array] -or $testNumbers.Count -eq 0 -or
      @($testNumbers | Where-Object { $_ -isnot [int] -and $_ -isnot [long] }).Count -gt 0) {
    throw 'testNumbers must be a non-empty JSON array of integers.'
  }
  $metadata = $MetadataJson | ConvertFrom-Json
  if ($metadata.primaryIssue -isnot [int] -and $metadata.primaryIssue -isnot [long]) {
    throw 'metadata.primaryIssue must be an integer.'
  }
  if ([string]$metadata.runId -notmatch '^[0-9]+$') {
    throw 'metadata.runId must be numeric.'
  }

  if (Test-RemoteBranchExists -Branch $IntegrationBranch) {
    Write-PreparationResult -Success $true -Status 'already_exists'
    exit 0
  }

  Invoke-Git -Arguments @('config', 'user.name', 'tegos-project-automation[bot]')
  Invoke-Git -Arguments @('config', 'user.email', 'tegos-project-automation[bot]@users.noreply.github.com')
  Invoke-Git -Arguments @('fetch', '--no-tags', 'origin', "refs/heads/$DefaultBranch`:refs/remotes/origin/$DefaultBranch")
  foreach ($branch in $branches) {
    Invoke-Git -Arguments @('fetch', '--no-tags', 'origin', "refs/heads/$branch`:refs/remotes/origin/$branch")
  }

  Invoke-Git -Arguments @('checkout', '-B', $IntegrationBranch, "origin/$DefaultBranch")
  $remoteBranches = @($branches | ForEach-Object { "origin/$_" })
  try {
    Merge-GitBranchesSequentially -Branches $remoteBranches
  } catch {
    $currentConflictBranch = [string]$_.Exception.Data['ConflictBranch']
    $currentConflictBranch = $currentConflictBranch -replace '^origin/', ''
    $currentConflictFiles = @($_.Exception.Data['ConflictFiles'])
    throw
  }

  $markedApps = @(Set-TestAppBriefs -TestNumbers @($testNumbers | ForEach-Object { [int]$_ }))
  $metadata | Add-Member -NotePropertyName apps -NotePropertyValue $markedApps -Force
  [System.IO.Directory]::CreateDirectory((Join-Path (Get-Location) '.itb')) | Out-Null
  $metadataPath = Join-Path (Get-Location) ".itb/$($metadata.runId).json"
  [System.IO.File]::WriteAllText(
    $metadataPath,
    (($metadata | ConvertTo-Json -Depth 100) + "`n"),
    [System.Text.UTF8Encoding]::new($false)
  )
  Invoke-Git -Arguments @('add', '--', ".itb/$($metadata.runId).json")
  Invoke-Git -Arguments @('commit', '-m', "Prepare integration test build $($metadata.runId) [skip ci]")
  Invoke-Git -Arguments @('push', '--set-upstream', 'origin', $IntegrationBranch)

  Write-PreparationResult -Success $true -Status 'prepared'
} catch {
  & git merge --abort 2>$null
  Write-PreparationResult -Success $false -Status 'failed' -Message $_.Exception.Message `
    -ConflictBranch $currentConflictBranch -ConflictFiles $currentConflictFiles
  Write-Error $_
  exit 1
}