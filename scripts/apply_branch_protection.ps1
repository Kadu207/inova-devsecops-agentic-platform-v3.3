param(
  [string]$Repo = "Kadu207/inova-devsecops-agentic-platform-v3.3",
  [string[]]$Branches = @("main"),
  [int]$ReviewCount = 1,
  [switch]$DryRun,
  [switch]$MakePublicIfRequired,
  [switch]$SkipWave7Checks
)

$ErrorActionPreference = "Stop"

$requiredChecks = @(
  "gates",
  "e2e-orchestrate-audit",
  "ci",
  "security"
)
if (-not $SkipWave7Checks) {
  $requiredChecks += @("gitleaks", "trivy")
}

Write-Host "==> Branch protection: $Repo"
Write-Host "    Branches: $($Branches -join ', ')"
Write-Host "    Required checks: $($requiredChecks -join ', ')"

function Get-RepoVisibility {
  gh api "repos/$Repo" --jq .visibility
}

function Set-RepoPublic {
  Write-Host "==> Tornando $Repo publico (GitHub Free exige repo publico para proteger a main)"
  gh repo edit $Repo --visibility public --accept-visibility-change-consequences
}

function Apply-Protection([string]$Branch) {
  $payload = @{
    required_status_checks = @{
      strict = $true
      checks = @($requiredChecks | ForEach-Object { @{ context = $_ } })
    }
    enforce_admins = $true
    required_pull_request_reviews = @{
      required_approving_review_count = $ReviewCount
      require_code_owner_reviews = $false
    }
    restrictions = $null
    required_linear_history = $false
    allow_force_pushes = $false
    allow_deletions = $false
    block_creations = $false
    required_conversation_resolution = $true
  } | ConvertTo-Json -Depth 6 -Compress

  $tmp = New-TemporaryFile
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($tmp.FullName, $payload, $utf8NoBom)
  try {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = gh api -X PUT "repos/$Repo/branches/$Branch/protection" --input $tmp.FullName 2>&1
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    return @{ Exit = $exit; Output = ($output | Out-String) }
  } finally {
    Remove-Item -Force $tmp.FullName
  }
}

if ($DryRun) {
  Write-Host "[dry-run] Nenhuma alteracao aplicada."
  exit 0
}

$visibility = Get-RepoVisibility
Write-Host "    Visibility atual: $visibility"

foreach ($branch in $Branches) {
  Write-Host "==> Aplicando protecao em '$branch'..."
  $result = Apply-Protection $branch
  if ($result.Exit -eq 0) {
    Write-Host "OK: protecao aplicada em $branch"
    continue
  }

  $text = $result.Output
  $needsPublic = ($text -match "403") -or ($text -match "Upgrade to GitHub Pro") -or ($text -match "make this repository public")
  if ($needsPublic -and $MakePublicIfRequired) {
    if ($visibility -ne "public") {
      Set-RepoPublic
      $visibility = "public"
    }
    $retry = Apply-Protection $branch
    if ($retry.Exit -ne 0) {
      Write-Host $retry.Output
      exit $retry.Exit
    }
    Write-Host "OK: protecao aplicada em $branch (repo publico)"
    continue
  }

  Write-Host $text
  exit $result.Exit
}

Write-Host "Branch protection concluida."
