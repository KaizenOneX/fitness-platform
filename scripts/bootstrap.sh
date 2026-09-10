#!/usr/bin/env bash
#
# bootstrap.sh — install the CLI toolbelt for the fitness-platform project.
#
# Commit this to scripts/bootstrap.sh. It exists so both machines run the same
# versions of everything; when something behaves differently on one laptop,
# this file is the first place to look.
#
# Docker is NOT installed here — it is platform-specific and needs a daemon.
# See the week 1 guide.
#
# Usage:  chmod +x bootstrap.sh && ./bootstrap.sh
#
set -euo pipefail

info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m!!\033[0m  %s\n' "$1"; }
die()   { printf '\033[1;31mxx\033[0m  %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Homebrew (works on macOS and Linux; keeps both machines on one package set)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Homebrew on Linux needs a C compiler and a few basics. Ubuntu ships without
# them, and the failure surfaces late — partway through installing a formula
# that needs to build from source (tilt was the one that caught us).
# ---------------------------------------------------------------------------

if [[ "$(uname -s)" == "Linux" ]] && ! command -v gcc >/dev/null 2>&1; then
  info "Installing build dependencies (needs sudo)"
  sudo apt-get update -qq
  sudo apt-get install -y build-essential procps curl file git
fi

if ! command -v brew >/dev/null 2>&1; then
  info "Homebrew not found — installing"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Linuxbrew does not add itself to PATH automatically
  if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    SHELL_RC="${HOME}/.bashrc"
    [[ -n "${ZSH_VERSION:-}" ]] && SHELL_RC="${HOME}/.zshrc"
    if ! grep -q linuxbrew "${SHELL_RC}" 2>/dev/null; then
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "${SHELL_RC}"
      warn "Added Homebrew to ${SHELL_RC} — restart your shell afterwards"
    fi
  fi
else
  info "Homebrew present"
fi

command -v brew >/dev/null 2>&1 || die "brew still not on PATH — restart your shell and re-run"

# ---------------------------------------------------------------------------
# Core toolbelt
# ---------------------------------------------------------------------------

CORE_TOOLS=(
  kubectl        # talk to clusters
  helm           # package manifests
  kustomize      # overlay manifests
  kind           # local clusters in docker
  k9s            # terminal UI for kubernetes; install this first, thank yourself later
  stern          # tail logs across many pods at once
  kubectx        # provides kubectx AND kubens
  argocd         # gitops CLI (used from week 11)
  jq             # json
  yq             # yaml
  direnv         # per-directory env vars
  gh             # github CLI
  go             # backend language
  golangci-lint  # go linter aggregator
)

info "Installing core tools"
for tool in "${CORE_TOOLS[@]}"; do
  if brew list "${tool}" >/dev/null 2>&1; then
    printf '    %-16s already installed\n' "${tool}"
  else
    printf '    %-16s installing...\n' "${tool}"
    brew install "${tool}" >/dev/null
  fi
done

# tilt lives in its own tap
info "Installing tilt"
if ! command -v tilt >/dev/null 2>&1; then
  brew install tilt-dev/tap/tilt >/dev/null
else
  echo "    tilt already installed"
fi

# ---------------------------------------------------------------------------
# Later-phase tools — uncomment as the plan reaches them
# ---------------------------------------------------------------------------
#
# Week 3  (module scaffolding)
#   brew install sqlc goose
#   go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest
#   go install github.com/fe3dback/go-arch-lint@latest
#
# Week 9  (CI, image scanning)
#   brew install trivy cosign syft
#
# Week 12 (AWS weekend 1)
#   brew install terraform awscli
#
# Week 24 (load testing)
#   brew install k6
#
# Week 25 (service mesh)
#   brew install linkerd
#
# Week 28+ (backup / restore)
#   brew install velero

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

echo
info "Versions — compare these against your teammate's output"
echo
printf '%-16s %s\n' "kubectl"       "$(kubectl version --client -o json 2>/dev/null | jq -r .clientVersion.gitVersion || echo '?')"
printf '%-16s %s\n' "helm"          "$(helm version --short 2>/dev/null || echo '?')"
printf '%-16s %s\n' "kustomize"     "$(kustomize version 2>/dev/null || echo '?')"
printf '%-16s %s\n' "kind"          "$(kind version 2>/dev/null || echo '?')"
printf '%-16s %s\n' "tilt"          "$(tilt version 2>/dev/null || echo '?')"
printf '%-16s %s\n' "k9s"           "$(k9s version -s 2>/dev/null | head -1 || echo '?')"
printf '%-16s %s\n' "argocd"        "$(argocd version --client --short 2>/dev/null || echo '?')"
printf '%-16s %s\n' "go"            "$(go version 2>/dev/null || echo '?')"
printf '%-16s %s\n' "gh"            "$(gh --version 2>/dev/null | head -1 || echo '?')"

echo
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  info "Docker daemon is reachable"
else
  warn "Docker is not running — install it per the week 1 guide, then:"
  warn "  kind create cluster --name fitness-dev --config kind-config.yaml"
fi

echo
info "Done. Next: kind create cluster --name fitness-dev --config kind-config.yaml"
