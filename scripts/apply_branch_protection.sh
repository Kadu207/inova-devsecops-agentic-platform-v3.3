#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-Kadu207/inova-devsecops-agentic-platform-v3.3}"
BRANCH="${2:-main}"
REVIEW_COUNT="${3:-1}"

export CHECKS="gates,e2e-orchestrate-audit,ci,security"
export REVIEW_COUNT

payload=$(python3 - <<'PY'
import json
import os

checks = [c.strip() for c in os.environ["CHECKS"].split(",") if c.strip()]
print(
    json.dumps(
        {
            "required_status_checks": {
                "strict": True,
                "checks": [{"context": c} for c in checks],
            },
            "enforce_admins": True,
            "required_pull_request_reviews": {
                "required_approving_review_count": int(os.environ["REVIEW_COUNT"]),
            },
            "restrictions": None,
            "allow_force_pushes": False,
            "allow_deletions": False,
            "required_conversation_resolution": True,
        }
    )
)
PY
)

echo "==> Branch protection: ${REPO} branch=${BRANCH}"

if ! gh api -X PUT "repos/${REPO}/branches/${BRANCH}/protection" --input - <<<"${payload}"; then
  echo ""
  echo "AVISO: Branch protection em repo privado exige GitHub Pro/Team."
  exit 2
fi

echo "Branch protection concluida."
