#!/bin/bash
# GitHub Repository Security Configuration Script
# Run this after creating the repository and pushing initial code
# Requirements: gh cli installed and authenticated (gh auth login)

set -e

# =============================================================================
# CONFIGURATION - Update these values
# =============================================================================
# Set default values if not provided
REPO=${1:-"OWNER/REPO"}  # Can be passed as first argument or edit here
BRANCH="main"

echo "🔧 Configuring GitHub repository: $REPO"

# =============================================================================
# SETTINGS
# =============================================================================

# Merge settings
ENABLE_SQUASH_MERGE=true
ENABLE_REBASE_MERGE=false
ENABLE_MERGE_COMMIT=false
DELETE_BRANCH_ON_MERGE=true
ENABLE_AUTO_MERGE=true

# Security settings
ENABLE_VULNERABILITY_ALERTS=true
ENABLE_DEPENDABOT_SECURITY_UPDATES=true
ENABLE_SECRET_SCANNING=true

# Branch protection ruleset settings
CREATE_BRANCH_RULESET=true
RESTRICT_DELETIONS=true
BLOCK_FORCE_PUSHES=true
REQUIRE_LINEAR_HISTORY=true
REQUIRE_SIGNED_COMMITS=false
REQUIRE_PULL_REQUEST=true
REQUIRED_APPROVING_REVIEWS=0
DISMISS_STALE_REVIEWS=true
REQUIRE_CODE_OWNER_REVIEW=false
REQUIRE_LAST_PUSH_APPROVAL=false
REQUIRE_REVIEW_THREAD_RESOLUTION=false
REQUIRE_STATUS_CHECKS=true
REQUIRE_BRANCHES_UP_TO_DATE=true
STATUS_CHECKS=('lint' 'type-check' 'test (3.11)' 'test (3.12)' 'test (3.13)' 'test (3.14)')

# Labels
CREATE_LABELS=true
# Define labels as "name|description|color"
LABELS=(
    "bug|Something isn't working|d73a4a"
    "enhancement|New feature or request|a2eeef"
    "documentation|Improvements or additions to docs|0075ca"
    "dependencies|Dependency updates|0366d6"
    "security|Security related issues|d93f0b"
    "good first issue|Good for newcomers|7057ff"
)

# =============================================================================
# SCRIPT START
# =============================================================================

# 1. General Settings
echo -e "\n📋 Updating general settings..."
REPO_EDIT_ARGS=("$REPO")

# Handling boolean flags for gh repo edit
if [ "$DELETE_BRANCH_ON_MERGE" = true ]; then REPO_EDIT_ARGS+=("--delete-branch-on-merge"); fi
if [ "$ENABLE_AUTO_MERGE" = true ]; then REPO_EDIT_ARGS+=("--enable-auto-merge"); fi
if [ "$ENABLE_SQUASH_MERGE" = true ]; then REPO_EDIT_ARGS+=("--enable-squash-merge"); fi

# These arguments take true/false values
REPO_EDIT_ARGS+=("--enable-rebase-merge=$ENABLE_REBASE_MERGE")
REPO_EDIT_ARGS+=("--enable-merge-commit=$ENABLE_MERGE_COMMIT")

gh repo edit "${REPO_EDIT_ARGS[@]}"

# 2. Security Settings
echo -e "\n🔒 Enabling security features..."
if [ "$ENABLE_VULNERABILITY_ALERTS" = true ]; then 
    gh api -X PUT "/repos/$REPO/vulnerability-alerts" --silent 2>/dev/null || true
fi

if [ "$ENABLE_DEPENDABOT_SECURITY_UPDATES" = true ]; then
    gh api -X PUT "/repos/$REPO/automated-security-fixes" --silent 2>/dev/null || true
fi

if [ "$ENABLE_SECRET_SCANNING" = true ]; then
    gh api -X PATCH "/repos/$REPO" -f security_and_analysis='{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}' --silent 2>/dev/null || true
fi

# 3. Branch Ruleset
if [ "$CREATE_BRANCH_RULESET" = true ]; then
    echo -e "\n🛡️  Creating branch ruleset..."
    
    RULES=()
    
    if [ "$RESTRICT_DELETIONS" = true ]; then RULES+=('{"type": "deletion"}'); fi
    if [ "$BLOCK_FORCE_PUSHES" = true ]; then RULES+=('{"type": "non_fast_forward"}'); fi
    if [ "$REQUIRE_LINEAR_HISTORY" = true ]; then RULES+=('{"type": "required_linear_history"}'); fi
    if [ "$REQUIRE_SIGNED_COMMITS" = true ]; then RULES+=('{"type": "required_signatures"}'); fi
    
    if [ "$REQUIRE_PULL_REQUEST" = true ]; then
        RULES+=("$(cat <<EOF
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": $REQUIRED_APPROVING_REVIEWS,
        "dismiss_stale_reviews_on_push": $DISMISS_STALE_REVIEWS,
        "require_code_owner_review": $REQUIRE_CODE_OWNER_REVIEW,
        "require_last_push_approval": $REQUIRE_LAST_PUSH_APPROVAL,
        "required_review_thread_resolution": $REQUIRE_REVIEW_THREAD_RESOLUTION
      }
    }
EOF
)")
    fi

    if [ "$REQUIRE_STATUS_CHECKS" = true ]; then
        # Construct checks array JSON
        CHECKS_JSON=""
        for check in "${STATUS_CHECKS[@]}"; do
            [ -n "$CHECKS_JSON" ] && CHECKS_JSON="$CHECKS_JSON,"
            CHECKS_JSON="$CHECKS_JSON{\"context\":\"$check\"}"
        done
        
        RULES+=("$(cat <<EOF
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": $REQUIRE_BRANCHES_UP_TO_DATE,
        "required_status_checks": [$CHECKS_JSON]
      }
    }
EOF
)")
    fi

    # Join rules with comma
    RULES_JSON=$(IFS=,; echo "${RULES[*]}")

    # GitHub ruleset payload
    # Note: bypass_actors ID 5 is RepositoryRole (admin/maintainer usually), check your specific needs or remove if not needed.
    # Here assuming standard RepositoryRole type.
    RULESET_PAYLOAD=$(cat <<EOF
{
  "name": "Main Branch Protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": [
        "refs/heads/$BRANCH"
      ],
      "exclude": []
    }
  },
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ],
  "rules": [$RULES_JSON]
}
EOF
)

    # Send request
    echo "$RULESET_PAYLOAD" | gh api -X POST "/repos/$REPO/rulesets" --input - >/dev/null || echo "  ⚠️  Ruleset creation failed (might already exist or permission issue)"
fi

# 4. Labels
if [ "$CREATE_LABELS" = true ]; then
    echo -e "\n🏷️  Creating labels..."
    for label_info in "${LABELS[@]}"; do
        IFS="|" read -r name desc color <<< "$label_info"
        gh label create "$name" --description "$desc" --color "$color" --repo "$REPO" --force 2>/dev/null || true
    done
fi

echo -e "\n🎉 Done!"
