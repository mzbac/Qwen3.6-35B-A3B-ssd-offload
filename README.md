# Qwen3.6-35B-A3B-ssd-offload

## Install

Install a release build and the default Qwen3.6 GGUF:

```bash
curl -fsSL https://raw.githubusercontent.com/mzbac/Qwen3.6-35B-A3B-ssd-offload/main/install.sh | sh
```

Install only the binary:

```bash
curl -fsSL https://raw.githubusercontent.com/mzbac/Qwen3.6-35B-A3B-ssd-offload/main/install.sh | sh -s -- --no-model
```

The installer puts the command in `$HOME/.local/bin` and the model in
`$HOME/.qw-agent/model` by default.

## Uninstall

Remove the installed binary, PATH marker, default model directory, app data, and
project-local `.qw-agent` memory/cache files:

```bash
curl -fsSL https://raw.githubusercontent.com/mzbac/Qwen3.6-35B-A3B-ssd-offload/main/uninstall.sh | sh
```

Use `--dry-run` to preview removals, `--keep-models` to avoid deleting the GGUF,
or `--keep-project-data` to keep local `.qw-agent/memory.md`.
