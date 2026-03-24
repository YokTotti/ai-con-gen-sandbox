# =============================================================================
# Claude Code - Sandbox Container（GAS / 単発作業 / 実験）
# 軽量構成: Node.js + Python (uv) + Claude Code
# =============================================================================
FROM ubuntu:24.04

ARG NODE_VERSION=22
ARG PYTHON_VERSION=3.13
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System dependencies（最小限）
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    jq \
    ripgrep \
    less \
    vim \
    openssh-client \
    unzip \
    tzdata \
    locales \
    && rm -rf /var/lib/apt/lists/*

# ロケール設定（UTF-8）
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# タイムゾーン設定（JST）
ENV TZ=Asia/Tokyo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ---------------------------------------------------------------------------
# Node.js
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# uv（Python パッケージマネージャ）
# ---------------------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/ \
    && mv /root/.local/bin/uvx /usr/local/bin/ \
    && rm -rf /root/.local

# ---------------------------------------------------------------------------
# gh CLI
# ---------------------------------------------------------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# clasp（Google Apps Script CLI）
# ---------------------------------------------------------------------------
RUN npm install -g @google/clasp

# ---------------------------------------------------------------------------
# 非 root ユーザー作成
# ---------------------------------------------------------------------------
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --force --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}

# ---------------------------------------------------------------------------
# ディレクトリ構成
# ---------------------------------------------------------------------------
RUN mkdir -p /home/${USERNAME}/project \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/project

RUN mkdir -p /home/${USERNAME}/.claude \
    && mkdir -p /home/${USERNAME}/.local/bin \
    && mkdir -p /home/${USERNAME}/.local/share \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.claude \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local

RUN mkdir -p /home/${USERNAME}/.config/gh \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config

# ---------------------------------------------------------------------------
# machine-id の設定（Docker コンテナでは空のため、ビルド時にランダム生成）
# ---------------------------------------------------------------------------
RUN cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id \
    && chmod 444 /etc/machine-id

# ---------------------------------------------------------------------------
# 非 root ユーザーに切り替え
# ---------------------------------------------------------------------------
USER ${USERNAME}

# ---------------------------------------------------------------------------
# vim 設定（矢印キー・Backspace 対応）
# ---------------------------------------------------------------------------
RUN echo 'set nocompatible\nset backspace=indent,eol,start\nset ttimeoutlen=100\nset encoding=utf-8\nset fileencodings=utf-8,euc-jp,sjis,cp932\nset fileformats=unix,dos,mac\nsyntax on' \
    > /home/${USERNAME}/.vimrc

# ---------------------------------------------------------------------------
# Claude Code（公式ネイティブインストーラー）
# ~/.local/bin/claude にインストールされる
# ---------------------------------------------------------------------------
RUN curl -fsSL https://claude.ai/install.sh | bash

# ---------------------------------------------------------------------------
# MCP サーバー設定テンプレート（chrome-devtools-mcp → ホスト Chrome）
# __HOST_IP__ は entrypoint.sh で実 IP に置換される
# 利用する場合は ~/project/.mcp.json にリネームしてください
# ---------------------------------------------------------------------------
RUN echo '{"mcpServers":{"chrome-devtools":{"command":"npx","args":["-y","chrome-devtools-mcp@latest","--no-usage-statistics","--browser-url=http://__HOST_IP__:9222"]}}}' \
    > /home/${USERNAME}/.mcp.json.chrome-devtool

# ---------------------------------------------------------------------------
# Bun
# ---------------------------------------------------------------------------
RUN curl -fsSL https://bun.com/install | bash

# ---------------------------------------------------------------------------
# Python（uv 経由）
# ---------------------------------------------------------------------------
RUN uv python install ${PYTHON_VERSION}

ENV PATH="/home/${USERNAME}/.bun/bin:/home/${USERNAME}/.local/bin:${PATH}"

# ---------------------------------------------------------------------------
# .bashrc: ~/.claude.json を shared volume に保存（EXIT trap + バックグラウンド定期コピー）
# ---------------------------------------------------------------------------
RUN cat >> /home/${USERNAME}/.bashrc <<'BASHRC'

# --- claude.json sync (EXIT trap + background periodic copy) ---
CLAUDE_SYNC_LOCK="/tmp/.claude-json-sync.lock"
trap 'flock -w 5 "$CLAUDE_SYNC_LOCK" cp "$HOME/.claude.json" "$HOME/.claude/.claude.json" 2>/dev/null' EXIT

# バックグラウンド定期コピー（docker kill/OOM/クラッシュ対策）
if [[ $- == *i* ]]; then
  (
    while sleep 30; do
      [ -f "$HOME/.claude.json" ] && \
        flock -n "$CLAUDE_SYNC_LOCK" cp "$HOME/.claude.json" "$HOME/.claude/.claude.json" 2>/dev/null
    done
  ) &
  disown
fi
BASHRC

# ---------------------------------------------------------------------------
# エントリポイント（起動時に MCP 設定をプロジェクトディレクトリへコピー）
# ---------------------------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} entrypoint.sh /home/${USERNAME}/.local/bin/entrypoint.sh
RUN chmod +x /home/${USERNAME}/.local/bin/entrypoint.sh

WORKDIR /home/${USERNAME}/project

ENTRYPOINT ["/home/coder/.local/bin/entrypoint.sh"]
CMD ["bash"]
