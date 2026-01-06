# GitHub Repository Security Configuration Script (PowerShell)
# Run this after creating the repository and pushing initial code
# Requirements: gh cli installed and authenticated (gh auth login)

$ErrorActionPreference = "Stop"

# =============================================================================
# CONFIGURATION - Update these values
# =============================================================================
$REPO = "OWNER/REPO"  # Update this!
$BRANCH = "main"

# -----------------------------------------------------------------------------
# MERGE SETTINGS
# -----------------------------------------------------------------------------
$ENABLE_SQUASH_MERGE = $true
$ENABLE_REBASE_MERGE = $false
$ENABLE_MERGE_COMMIT = $false
$DELETE_BRANCH_ON_MERGE = $true
$ENABLE_AUTO_MERGE = $true

# -----------------------------------------------------------------------------
# SECURITY SETTINGS
# -----------------------------------------------------------------------------
$ENABLE_VULNERABILITY_ALERTS = $true
$ENABLE_DEPENDABOT_SECURITY_UPDATES = $true
$ENABLE_SECRET_SCANNING = $true

# -----------------------------------------------------------------------------
# BRANCH RULESET SETTINGS
# -----------------------------------------------------------------------------
$CREATE_BRANCH_RULESET = $true
$RESTRICT_DELETIONS = $true
$BLOCK_FORCE_PUSHES = $true
$REQUIRE_LINEAR_HISTORY = $true
$REQUIRE_SIGNED_COMMITS = $false
$REQUIRE_PULL_REQUEST = $true
$REQUIRED_APPROVING_REVIEWS = 0
$DISMISS_STALE_REVIEWS = $true
$REQUIRE_CODE_OWNER_REVIEW = $false
$REQUIRE_LAST_PUSH_APPROVAL = $false
$REQUIRE_REVIEW_THREAD_RESOLUTION = $false
$REQUIRE_STATUS_CHECKS = $true
$REQUIRE_BRANCHES_UP_TO_DATE = $true
$STATUS_CHECKS = @("lint", "type-check", "test (3.12)")

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------
$CREATE_LABELS = $true
$LABELS = @(
    @{name="bug"; desc="Something isn't working"; color="d73a4a"},
    @{name="enhancement"; desc="New feature or request"; color="a2eeef"},
    @{name="documentation"; desc="Improvements or additions to docs"; color="0075ca"},
    @{name="dependencies"; desc="Dependency updates"; color="0366d6"},
    @{name="security"; desc="Security related issues"; color="d93f0b"},
    @{name="good first issue"; desc="Good for newcomers"; color="7057ff"}
)

# ... (rest of the script same as previous version)
# For brevity, I'll only include the configuration part in the template
# but in a real scenario, the full script should be here.
# I will write the full script to be safe.

# =============================================================================
# SCRIPT START
# =============================================================================
Write-Host "🔧 Configuring GitHub repository: $REPO" -ForegroundColor Cyan

# 1. General Settings
Write-Host "`n📋 Updating general settings..." -ForegroundColor Yellow
$repoEditArgs = @($REPO)
if ($DELETE_BRANCH_ON_MERGE) { $repoEditArgs += "--delete-branch-on-merge" }
if ($ENABLE_AUTO_MERGE) { $repoEditArgs += "--enable-auto-merge" }
if ($ENABLE_SQUASH_MERGE) { $repoEditArgs += "--enable-squash-merge" }
$repoEditArgs += "--enable-rebase-merge=$ENABLE_REBASE_MERGE"
$repoEditArgs += "--enable-merge-commit=$ENABLE_MERGE_COMMIT"
gh repo edit @repoEditArgs

# 2. Security Settings
Write-Host "`n🔒 Enabling security features..." -ForegroundColor Yellow
if ($ENABLE_VULNERABILITY_ALERTS) { try { gh api -X PUT "/repos/$REPO/vulnerability-alerts" 2>$null } catch {} }
if ($ENABLE_DEPENDABOT_SECURITY_UPDATES) { try { gh api -X PUT "/repos/$REPO/automated-security-fixes" 2>$null } catch {} }
if ($ENABLE_SECRET_SCANNING) { try { gh api -X PATCH "/repos/$REPO" -f security_and_analysis='{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}' 2>$null } catch {} }

# 3. Branch Ruleset
if ($CREATE_BRANCH_RULESET) {
    Write-Host "`n🛡️  Creating branch ruleset..." -ForegroundColor Yellow
    $rules = @()
    if ($RESTRICT_DELETIONS) { $rules += '{"type": "deletion"}' }
    if ($BLOCK_FORCE_PUSHES) { $rules += '{"type": "non_fast_forward"}' }
    if ($REQUIRE_LINEAR_HISTORY) { $rules += '{"type": "required_linear_history"}' }
    if ($REQUIRE_SIGNED_COMMITS) { $rules += '{"type": "required_signatures"}' }
    if ($REQUIRE_PULL_REQUEST) {
        $rules += @"
{
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": $REQUIRED_APPROVING_REVIEWS,
        "dismiss_stale_reviews_on_push": $($DISMISS_STALE_REVIEWS.ToString().ToLower()),
        "require_code_owner_review": $($REQUIRE_CODE_OWNER_REVIEW.ToString().ToLower()),
        "require_last_push_approval": $($REQUIRE_LAST_PUSH_APPROVAL.ToString().ToLower()),
        "required_review_thread_resolution": $($REQUIRE_REVIEW_THREAD_RESOLUTION.ToString().ToLower())
      }
    }
"@
    }
    if ($REQUIRE_STATUS_CHECKS) {
        $statusChecksJson = ($STATUS_CHECKS | ForEach-Object { "{`"context`":`"$_`"}" }) -join ","
        $rules += @"
{
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": $($REQUIRE_BRANCHES_UP_TO_DATE.ToString().ToLower()),
        "required_status_checks": [$statusChecksJson]
      }
    }
"@
    }
    $rulesJson = $rules -join ","
    $rulesetJson = "{`"name`":`"Main Branch Protection`",`"target`":`"branch`",`"enforcement`":`"active`",`"conditions`":{`"ref_name`":{`"include`":[`"refs/heads/$BRANCH`"],`"exclude`":[]}},`"bypass_actors`":[{`"actor_id`":5,`"actor_type`":`"RepositoryRole`",`"bypass_mode`":`"always`"}],`"rules`":[$rulesJson]}"
    try { $rulesetJson | gh api -X POST "/repos/$REPO/rulesets" --input - } catch { Write-Host "  ⚠️  Ruleset error" }
}

# 4. Labels
if ($CREATE_LABELS) {
    Write-Host "`n🏷️  Creating labels..." -ForegroundColor Yellow
    foreach ($label in $LABELS) { try { gh label create $label.name --description $label.desc --color $label.color --repo $REPO 2>$null } catch {} }
}

Write-Host "`n🎉 Done!" -ForegroundColor Green
