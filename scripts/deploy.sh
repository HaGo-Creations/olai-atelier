#!/usr/bin/env bash
# scripts/deploy.sh
# Commits all changes, pushes to GitHub main, and pushes
# the backend/ subtree to the Hugging Face Space.
#
# Usage:
#   ./scripts/deploy.sh "your commit message"
#   ./scripts/deploy.sh           (prompts for message)
#
# Requirements:
#   git, huggingface-cli (pip install huggingface_hub[cli])
#   HF token set via:  huggingface-cli login
#        OR:           export HF_TOKEN=hf_xxxx

set -e
cd "$(dirname "$0")/.."

GITHUB_REMOTE="origin"
GITHUB_BRANCH="main"
HF_SPACE="hago-creations/gemma-educator"
HF_REMOTE="https://huggingface.co/spaces/${HF_SPACE}"

# ── Commit message ─────────────────────────────────────────────────────────
MSG="${1:-}"
if [[ -z "$MSG" ]]; then
    read -rp "Commit message: " MSG
fi
MSG="${MSG:-Update}"

echo ""
echo "============================================================"
echo " Deploying: $MSG"
echo "============================================================"
echo ""

# ── Step 1: Stage and commit ───────────────────────────────────────────────
echo "[1/4] Staging all changes..."
git add -A
git status --short
echo ""

if git diff --cached --quiet; then
    echo "  Nothing to commit — working tree clean."
else
    git commit -m "$MSG"
    echo "  Committed."
fi

# ── Step 2: Merge worktree branch into main ────────────────────────────────
echo ""
echo "[2/4] Merging to $GITHUB_BRANCH..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" == "$GITHUB_BRANCH" ]]; then
    echo "  Already on $GITHUB_BRANCH."
else
    git checkout "$GITHUB_BRANCH"
    git merge --no-ff "$CURRENT_BRANCH" -m "Merge $CURRENT_BRANCH into $GITHUB_BRANCH"
    echo "  Merged $CURRENT_BRANCH into $GITHUB_BRANCH."
fi

# ── Step 3: Push to GitHub ─────────────────────────────────────────────────
echo ""
echo "[3/4] Pushing to GitHub ($GITHUB_REMOTE/$GITHUB_BRANCH)..."
git push "$GITHUB_REMOTE" "$GITHUB_BRANCH"
echo "  GitHub push successful."
echo "  GitHub Actions will now build and deploy the Flutter web app."

# ── Step 4: Push backend to Hugging Face Space ────────────────────────────
echo ""
echo "[4/4] Pushing backend/ to Hugging Face Space..."

if ! git remote get-url hf &>/dev/null; then
    git remote add hf "$HF_REMOTE"
    echo "  Added HF remote: $HF_REMOTE"
fi

git subtree push --prefix=backend hf main || {
    echo "  Subtree push failed — trying force approach..."
    git push hf "$(git subtree split --prefix=backend "$GITHUB_BRANCH")":main --force
}
echo "  Hugging Face push successful."

echo ""
echo "============================================================"
echo " Deployment complete."
echo " GitHub  : https://github.com/HaGo-Creations/gemma4-edtech-ai-assistant"
echo " HF Space: https://huggingface.co/spaces/${HF_SPACE}"
echo " Live app : https://HaGo-Creations.github.io/gemma4-edtech-ai-assistant"
echo "============================================================"
