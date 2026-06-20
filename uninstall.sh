#!/usr/bin/env sh

set -eu

APP_NAME="qw-agent"
INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
MODEL_DIR="${MODEL_DIR:-"$HOME/.qw-agent/model"}"
BIN_NAME="${BIN_NAME:-"$APP_NAME"}"
APP_HOME="${APP_HOME:-"$HOME/.qw-agent"}"
PROJECT_DATA_DIR="${PROJECT_DATA_DIR:-".qw-agent"}"
MODIFY_PATH=1
REMOVE_MODELS=1
REMOVE_APP_HOME=1
REMOVE_PROJECT_DATA=1
CUSTOM_MODEL_DIR=0
DRY_RUN=0

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

usage() {
  cat <<USAGE
Uninstall $APP_NAME.

Usage:
  uninstall.sh [options]

Options:
  --install-dir DIR       Directory containing the installed binary. Default: \$HOME/.local/bin
  --bin-name NAME         Installed command name. Default: qw-agent
  --app-home DIR          Remove app data from DIR. Default: \$HOME/.qw-agent
  --model-dir DIR         Remove models from DIR too. Default: \$HOME/.qw-agent/model
  --project-data-dir DIR  Remove project memory/cache dir too. Default: ./.qw-agent
  --keep-models           Keep model files
  --keep-data             Keep \$HOME/.qw-agent
  --keep-project-data     Keep project-local .qw-agent memory/cache files
  --no-modify-path        Do not update shell startup files
  --dry-run               Print what would be removed without deleting files
  -h, --help              Show this help

Examples:
  curl -fsSL https://raw.githubusercontent.com/mzbac/Qwen3.6-35B-A3B-ssd-offload/main/uninstall.sh | sh

  curl -fsSL https://raw.githubusercontent.com/mzbac/Qwen3.6-35B-A3B-ssd-offload/main/uninstall.sh \\
    | sh -s -- --install-dir "\$HOME/bin"

  ./uninstall.sh --dry-run
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      [ "$#" -ge 2 ] || die "--install-dir requires a value"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --bin-name)
      [ "$#" -ge 2 ] || die "--bin-name requires a value"
      BIN_NAME="$2"
      shift 2
      ;;
    --app-home)
      [ "$#" -ge 2 ] || die "--app-home requires a value"
      APP_HOME="$2"
      shift 2
      ;;
    --model-dir)
      [ "$#" -ge 2 ] || die "--model-dir requires a value"
      MODEL_DIR="$2"
      CUSTOM_MODEL_DIR=1
      shift 2
      ;;
    --project-data-dir)
      [ "$#" -ge 2 ] || die "--project-data-dir requires a value"
      PROJECT_DATA_DIR="$2"
      shift 2
      ;;
    --keep-models)
      REMOVE_MODELS=0
      shift
      ;;
    --keep-data)
      REMOVE_APP_HOME=0
      shift
      ;;
    --keep-project-data)
      REMOVE_PROJECT_DATA=0
      shift
      ;;
    --no-modify-path)
      MODIFY_PATH=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

normalize_dir() {
  case "$1" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${1#~/}"
      ;;
    /*)
      printf '%s\n' "$1"
      ;;
    *)
      printf '%s/%s\n' "$(pwd)" "$1"
      ;;
  esac
}

same_path() {
  [ "$1" = "$2" ] || [ "$1/" = "$2" ] || [ "$1" = "$2/" ]
}

path_under() {
  child="$1"
  parent="$2"
  case "$child/" in
    "$parent/"*) return 0 ;;
    *) return 1 ;;
  esac
}

safe_rm_rf() {
  path="$1"
  [ -n "$path" ] || die "refusing to remove an empty path"
  case "$path" in
    "/"|"$HOME"|"$HOME/"|"$INSTALL_DIR"|"$INSTALL_DIR/")
      die "refusing to remove unsafe path: $path"
      ;;
  esac
  if [ -e "$path" ] || [ -L "$path" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      info "Would remove: $path"
    else
      rm -rf "$path"
      info "Removed: $path"
    fi
  else
    info "Not present: $path"
  fi
}

safe_rm_file() {
  path="$1"
  [ -n "$path" ] || die "refusing to remove an empty path"
  if [ -e "$path" ] || [ -L "$path" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      info "Would remove: $path"
    else
      rm -f "$path"
      info "Removed: $path"
    fi
  else
    info "Not present: $path"
  fi
}

remove_path_markers_file() {
  rc_file="$1"
  [ "$MODIFY_PATH" -eq 1 ] || return 0
  [ -f "$rc_file" ] || return 0

  marker="# Added by $APP_NAME installer"
  if ! grep -F "$marker" "$rc_file" >/dev/null 2>&1; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    info "Would remove PATH block from: $rc_file"
    return 0
  fi

  tmp_file="$rc_file.$APP_NAME-uninstall.$$"
  awk -v marker="$marker" '
    $0 == marker { skip = 1; next }
    skip == 1 { skip = 0; next }
    { print }
  ' "$rc_file" > "$tmp_file"
  mv "$tmp_file" "$rc_file"
  info "Removed PATH block from: $rc_file"
}

main() {
  INSTALL_DIR="$(normalize_dir "$INSTALL_DIR")"
  MODEL_DIR="$(normalize_dir "$MODEL_DIR")"
  APP_HOME="$(normalize_dir "$APP_HOME")"
  PROJECT_DATA_DIR="$(normalize_dir "$PROJECT_DATA_DIR")"

  info "Uninstalling $APP_NAME"
  info "Install dir: $INSTALL_DIR"
  info "App data dir: $APP_HOME"
  info "Model dir: $MODEL_DIR"
  info "Project data dir: $PROJECT_DATA_DIR"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry run: no files will be removed"
  fi

  safe_rm_file "$INSTALL_DIR/$BIN_NAME"

  if [ "$REMOVE_MODELS" -eq 0 ] && path_under "$MODEL_DIR" "$APP_HOME"; then
    REMOVE_APP_HOME=0
    info "Keeping app data dir because it contains the kept model dir"
  fi

  if [ "$REMOVE_APP_HOME" -eq 1 ]; then
    safe_rm_rf "$APP_HOME"
  fi

  if [ "$REMOVE_MODELS" -eq 1 ]; then
    if [ "$REMOVE_APP_HOME" -eq 0 ]; then
      safe_rm_rf "$MODEL_DIR"
    elif [ "$CUSTOM_MODEL_DIR" -eq 1 ] && ! path_under "$MODEL_DIR" "$APP_HOME"; then
      safe_rm_rf "$MODEL_DIR"
    fi
  fi

  if [ "$REMOVE_PROJECT_DATA" -eq 1 ]; then
    if same_path "$PROJECT_DATA_DIR" "$APP_HOME"; then
      info "Project data dir already handled by app data dir: $PROJECT_DATA_DIR"
    else
      safe_rm_rf "$PROJECT_DATA_DIR"
    fi
  fi

  remove_path_markers_file "$HOME/.zshrc"
  remove_path_markers_file "$HOME/.bashrc"
  remove_path_markers_file "$HOME/.profile"

  info ""
  info "$APP_NAME uninstall complete."
}

main "$@"
