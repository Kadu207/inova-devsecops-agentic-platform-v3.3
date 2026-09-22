#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-Kadu207/inova-devsecops-agentic-platform-v3.3}"
BRANCH="${2:-main}"
REVIEW_COUNT="${3:-1}"
MAKE_PUBLIC="${MAKE_PUBLIC_IF_REQUIRED:-1}"
SKIP_WAVE7="${SKIP_WAVE7_CHECKS:-0}"

if [[ "$SKIP_WAVE7" == "1" ]]; then
  export CHECKS="gates,e2e-orchestrate-audit,ci,security"
else
  export CHECKS="gates,e2e-orchestrate-audit,ci,security,gitleaks,trivy"
fi
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
echo "    Checks: ${CHECKS}"

apply() {
  gh api -X PUT "repos/${REPO}/branches/${BRANCH}/protection" --input - <<<"${payload}"
}

if apply; then
  echo "Branch protection concluida."
  exit 0
fi

if [[ "$MAKE_PUBLIC" == "1" ]]; then
  echo "==> 403/plano Free — tornando o repositorio publico"
  gh repo edit "${REPO}" --visibility public --accept-visibility-change-consequences
  apply
  echo "Branch protection concluida (repo publico)."
  exit 0
fi

echo "AVISO: Branch protection em repo privado exige GitHub Pro/Team."
exit 2
