#!/usr/bin/env bash
# setup-audio-separator.sh — unwa "Instrumental v1e plus" vocal/instrumental
# separation model (MelBand-Roformer Kim FT) + the audio-separator CLI.
# Idempotent: safe to re-run (resumable downloads, no-op when installed).
#
# Why this exists — two gotchas in audio-separator 0.44.x:
#   1. The CLI's default model_file_dir is /tmp/audio-separator-models/,
#      which is wiped on reboot. Models belong in a persistent dir, so we
#      pin AUDIO_SEPARATOR_MODEL_DIR.
#   2. The model registry expects the UVR filename
#      melband_roformer_inst_v1e_plus.ckpt, but the HF repo ships it as
#      inst_v1e_plus.ckpt — without the rename the registry lookup fails.
#
# What it does:
#   1. installs audio-separator (uv tool; falls back to pipx, then venv+pip)
#   2. ensures the model dir exists (default ~/.audio_separator/models)
#   3. downloads the ckpt (913 MB) + config yaml from HF pcunwa/Mel-Band-Roformer-Inst
#   4. appends AUDIO_SEPARATOR_MODEL_DIR to ~/.bashrc if missing
#   5. verifies: `audio-separator --list_models` lists the model
#
# All user-level — no sudo. Usage:
#   ./setup-audio-separator.sh
set -euo pipefail

MODEL_DIR="${AUDIO_SEPARATOR_MODEL_DIR:-$HOME/.audio_separator/models}"
CKPT="melband_roformer_inst_v1e_plus.ckpt"
CFG="config_melbandroformer_inst.yaml"
HF_BASE="https://huggingface.co/pcunwa/Mel-Band-Roformer-Inst/resolve/main"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

# 1. Tool ---------------------------------------------------------------
if ! command -v audio-separator >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    log "installing audio-separator via uv tool"
    uv tool install audio-separator
  elif command -v pipx >/dev/null 2>&1; then
    log "installing audio-separator via pipx"
    pipx install audio-separator
  else
    log "installing audio-separator via venv+pip (no uv/pipx found)"
    python3 -m venv "$HOME/.venvs/audio-separator"
    "$HOME/.venvs/audio-separator/bin/pip" install -U audio-separator
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.venvs/audio-separator/bin/audio-separator" "$HOME/.local/bin/audio-separator"
  fi
else
  log "audio-separator present: $(audio-separator --version 2>/dev/null | tail -1)"
fi

# 2. Model dir -----------------------------------------------------------
mkdir -p "$MODEL_DIR"

# 3. Model + config ------------------------------------------------------
if [ -f "$MODEL_DIR/$CKPT" ]; then
  log "have $CKPT — skipping (resume: rm it to re-download)"
else
  log "downloading inst_v1e_plus.ckpt (913 MB) from HF"
  curl -L --fail --retry 3 -C - -o "$MODEL_DIR/inst_v1e_plus.ckpt" "$HF_BASE/inst_v1e_plus.ckpt"
  mv "$MODEL_DIR/inst_v1e_plus.ckpt" "$MODEL_DIR/$CKPT"   # registry expects UVR name
fi
if [ -f "$MODEL_DIR/$CFG" ]; then
  log "have $CFG — skipping"
else
  log "downloading $CFG"
  curl -L --fail --retry 3 -C - -o "$MODEL_DIR/$CFG" "$HF_BASE/$CFG"
fi

# 4. Persistent env var ----------------------------------------------------
if ! grep -qs "AUDIO_SEPARATOR_MODEL_DIR" "$HOME/.bashrc"; then
  log "appending AUDIO_SEPARATOR_MODEL_DIR to ~/.bashrc"
  # quoted 'EOF' keeps $HOME literal — expands when .bashrc is sourced, not now
  cat >> "$HOME/.bashrc" <<'EOF'

# audio-separator: keep models in a persistent dir (CLI default is /tmp)
export AUDIO_SEPARATOR_MODEL_DIR="$HOME/.audio_separator/models"
EOF
fi

# 5. Verify ----------------------------------------------------------------
log "verifying model registration..."
if AUDIO_SEPARATOR_MODEL_DIR="$MODEL_DIR" audio-separator --list_models 2>/dev/null | grep -q "melband_roformer_inst_v1e_plus"; then
  log "OK — model registered."
  log "Usage: audio-separator --model_filename melband_roformer_inst_v1e_plus.ckpt <song>"
else
  warn "model not listed — check contents of $MODEL_DIR"
  exit 1
fi
