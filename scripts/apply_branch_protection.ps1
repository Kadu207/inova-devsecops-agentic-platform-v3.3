param(
  [string]$Repo = "Kadu207/inova-devsecops-agentic-platform-v3.3",
  [string[]]$Branches = @("main"),
  [int]$ReviewCount = 1,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$requiredChecks = @(
  "gates",
  "e2e-orchestrate-audit",
  "ci",
  "security"
)

Write-Host "==> Branch protection: $Repo"
Write-Host "    Branches: $($Branches -join ', ')"
Write-Host "    Required checks: $($requiredChecks -join ', ')"

if ($DryRun) {
  Write-Host "[dry-run] Nenhuma alteracao aplicada."
  exit 0
}

foreach ($branch in $Branches) {
  Write-Host "==> Aplicando protecao em '$branch'..."

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
    $output = gh api -X PUT "repos/$Repo/branches/$branch/protection" --input $tmp.FullName 2>&1
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($exit -ne 0) {
      $text = ($output | Out-String)
      if ($text -match "403" -or $text -match "Upgrade to GitHub Pro") {
        Write-Host ""
        Write-Host "AVISO: Branch protection em repo privado exige GitHub Pro/Team."
        Write-Host "Alternativas:"
        Write-Host "  1. Upgrade do plano GitHub"
        Write-Host "  2. MCP github-governance-mcp-local (Cursor) quando plano permitir"
        Write-Host "  3. Confiar nos workflows CI ate upgrade (PRs ainda rodam checks)"
        exit 2
      }
      Write-Host $text
      exit $exit
    }
    Write-Host "OK: protecao aplicada em $branch"
  } finally {
    Remove-Item -Force $tmp.FullName
  }
}

Write-Host "Branch protection concluida."
