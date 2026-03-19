#!/bin/bash
# =============================================================================
# entrypoint.sh — コンテナ起動時の初期化処理
# =============================================================================

# ---------------------------------------------------------------------------
# shared volume のオーナーシップ修正
# named volume が別コンテナで作成された場合、UID/GID が異なる可能性がある
# ---------------------------------------------------------------------------
if [ -d "$HOME/.claude" ]; then
    # 自分のものでないファイルがあれば修正を試みる（エラーは無視）
    find "$HOME/.claude" ! -user "$(id -u)" -exec chown "$(id -u):$(id -g)" {} + 2>/dev/null || true
fi

if [ -d "$HOME/.config/gh" ]; then
    find "$HOME/.config/gh" ! -user "$(id -u)" -exec chown "$(id -u):$(id -g)" {} + 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# ~/.claude.json の永続化（コピー方式）
# volume 上の ~/.claude/.claude.json ↔ コンテナ上の ~/.claude.json をコピーで同期
# symlink は Claude CLI の atomic write（temp → rename）で上書きされるため使用しない
# ---------------------------------------------------------------------------

# 起動時: volume → コンテナに復元
if [ -f "$HOME/.claude/.claude.json" ]; then
    # shared volume が source of truth — 常にそこから復元
    cp "$HOME/.claude/.claude.json" "$HOME/.claude.json"
    echo "[entrypoint] ✓ ~/.claude.json を shared volume から復元"
elif [ -f "$HOME/.claude.json" ] && [ ! -L "$HOME/.claude.json" ]; then
    # volume に保存がない + コンテナに存在（初回ビルド後）→ volume にシード
    cp "$HOME/.claude.json" "$HOME/.claude/.claude.json"
fi

# ---------------------------------------------------------------------------
# MCP 設定テンプレートをプロジェクトディレクトリにコピー
# named volume にはビルド時の書き込みが反映されないため、起動時にコピーする
# ---------------------------------------------------------------------------
if [ -f "$HOME/.mcp.json.chrome-devtool" ] && [ ! -f "$HOME/project/.mcp.json.chrome-devtool" ]; then
    HOST_IP=$(getent ahostsv4 host.docker.internal | awk 'NR==1{print $1}')
    if [ -n "$HOST_IP" ]; then
        sed "s/__HOST_IP__/$HOST_IP/g" "$HOME/.mcp.json.chrome-devtool" > "$HOME/project/.mcp.json.chrome-devtool"
        echo "[entrypoint] ✓ MCP テンプレートをコピー（host IP: $HOST_IP）"
    else
        echo "[entrypoint] ⚠ host.docker.internal を解決できません — MCP テンプレートはスキップ"
    fi
fi

# ---------------------------------------------------------------------------
# Claude CLI 認証状態のログ出力（デバッグ用）
# ---------------------------------------------------------------------------
if [ -f "$HOME/.claude/.credentials.json" ]; then
    expires_at=$(jq -r '
        (.claudeAiOauth // empty | .accessToken // empty) as $token |
        if $token then
            .claudeAiOauth.expiresAt // "unknown"
        else
            "no_token"
        end
    ' "$HOME/.claude/.credentials.json" 2>/dev/null || echo "parse_error")

    if [ "$expires_at" != "no_token" ] && [ "$expires_at" != "unknown" ] && [ "$expires_at" != "parse_error" ]; then
        now_ms=$(date +%s%3N 2>/dev/null || echo "0")
        if [ "$now_ms" != "0" ] && [ "$expires_at" -lt "$now_ms" ] 2>/dev/null; then
            echo "[entrypoint] ⚠ Claude CLI アクセストークンの有効期限が切れています（expiresAt: $expires_at）"
            echo "[entrypoint]   再認証が必要な場合は 'claude' を実行してください"
        else
            echo "[entrypoint] ✓ Claude CLI 認証情報を検出（有効期限内）"
        fi
    fi
else
    echo "[entrypoint] Claude CLI 未認証（.credentials.json が見つかりません）"
fi

# ---------------------------------------------------------------------------
# machine-id 空チェック（デバッグ用）
# ---------------------------------------------------------------------------
if [ ! -s /etc/machine-id ]; then
    echo "[entrypoint] ⚠ /etc/machine-id が空です — Claude CLI の認証が保持されない可能性があります"
fi

# ---------------------------------------------------------------------------
# CMD を exec で実行（PID 1 は tini が担当、シグナル転送は init: true で処理）
# ~/.claude.json の保存は .bashrc の EXIT trap で行う
# ---------------------------------------------------------------------------
exec "$@"
