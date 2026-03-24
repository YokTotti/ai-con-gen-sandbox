# =============================================================================
# Claude Code - Web Application Development Container
# Node.js / Go / Python (uv) / pnpm / Playwright
# =============================================================================
FROM ubuntu:24.04

# ---------------------------------------------------------------------------
# Build arguments — バージョンはここで一元管理
# ---------------------------------------------------------------------------
ARG NODE_VERSION=22
ARG GO_VERSION=1.25.0
ARG PYTHON_VERSION=3.13
ARG PNPM_VERSION=10
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=1000
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基本ツール
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    libssl-dev \
    pkg-config \
    unzip \
    jq \
    ripgrep \
    fd-find \
    less \
    vim \
    openssh-client \
    sudo \
    # Playwright 用 system dependencies（chromium）
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2t64 \
    fonts-noto-cjk \
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
# pnpm（corepack 経由）
# ---------------------------------------------------------------------------
RUN corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate

# ---------------------------------------------------------------------------
# Go — TARGETARCH で Apple Silicon (arm64) にも対応
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" \
    | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:${PATH}"

# ---------------------------------------------------------------------------
# uv（Python パッケージマネージャ）— システムワイドにインストール
# ---------------------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/ \
    && mv /root/.local/bin/uvx /usr/local/bin/ \
    && rm -rf /root/.local

# ---------------------------------------------------------------------------
# gh CLI（GitHub CLI）
# ---------------------------------------------------------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 非 root ユーザー作成
# ---------------------------------------------------------------------------
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --force --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}

# ---------------------------------------------------------------------------
# ディレクトリ構成 & パーミッション
# ---------------------------------------------------------------------------
# プロジェクトディレクトリ
RUN mkdir -p /home/${USERNAME}/project \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/project

# Go workspace
ENV GOPATH="/home/${USERNAME}/go"
ENV PATH="${GOPATH}/bin:/home/${USERNAME}/.bun/bin:/home/${USERNAME}/.local/bin:${PATH}"
RUN mkdir -p ${GOPATH}/{bin,src,pkg} \
    && chown -R ${USERNAME}:${USERNAME} ${GOPATH}

# Claude Code 設定・データディレクトリ
RUN mkdir -p /home/${USERNAME}/.claude \
    && mkdir -p /home/${USERNAME}/.local/bin \
    && mkdir -p /home/${USERNAME}/.local/share \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.claude

# gh CLI 設定ディレクトリ
RUN mkdir -p /home/${USERNAME}/.config/gh \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config

# pnpm store ディレクトリ
RUN mkdir -p /home/${USERNAME}/.local/share/pnpm \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local

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
# npm install は非推奨のため使用しない
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
# Python（uv 経由でインストール）
# ---------------------------------------------------------------------------
RUN uv python install ${PYTHON_VERSION}

# ---------------------------------------------------------------------------
# Playwright（Chromium のみ — ブラウザバイナリ）
# ---------------------------------------------------------------------------
RUN npx playwright install chromium

# ---------------------------------------------------------------------------
# シェル設定
# ---------------------------------------------------------------------------
RUN echo 'export PATH="/home/${USERNAME}/.local/bin:$PATH"' >> /home/${USERNAME}/.bashrc \
    && echo 'export GOPATH="/home/${USERNAME}/go"' >> /home/${USERNAME}/.bashrc \
    && echo 'export PATH="$GOPATH/bin:$PATH"' >> /home/${USERNAME}/.bashrc \
    && echo 'export BUN_INSTALL="$HOME/.bun"' >> /home/${USERNAME}/.bashrc \
    && echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /home/${USERNAME}/.bashrc \
    && cat >> /home/${USERNAME}/.bashrc <<'BASHRC'

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
