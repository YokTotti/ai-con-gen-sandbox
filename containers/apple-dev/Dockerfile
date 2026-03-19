# =============================================================================
# Claude Code - macOS / iOS Development Assist Container
# Swift toolchain + コード解析ツール（Linux 上でのビルド補助・レビュー用途）
# =============================================================================
FROM ubuntu:24.04

ARG SWIFT_VERSION=6.1
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=1000
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    # Swift runtime dependencies
    libcurl4-openssl-dev \
    libxml2-dev \
    libedit-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libz-dev \
    binutils \
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
# Swift toolchain
# TARGETARCH に応じて aarch64 / x86_64 を切り替え
# ---------------------------------------------------------------------------
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
        SWIFT_PLATFORM="ubuntu2404-aarch64"; \
        SWIFT_SUFFIX="-aarch64"; \
    else \
        SWIFT_PLATFORM="ubuntu2404"; \
        SWIFT_SUFFIX=""; \
    fi \
    && SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/${SWIFT_PLATFORM}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04${SWIFT_SUFFIX}.tar.gz" \
    && curl -fsSL "${SWIFT_URL}" | tar -C /usr/local --strip-components=2 -xzf -

# Swift にパスを通す
ENV PATH="/usr/local/bin:${PATH}"

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
# Node.js 不要 — ~/.local/bin/claude にインストールされる
# ---------------------------------------------------------------------------
RUN curl -fsSL https://claude.ai/install.sh | bash

# ---------------------------------------------------------------------------
# シェル設定
# ---------------------------------------------------------------------------
RUN echo 'export PATH="/home/coder/.local/bin:$PATH"' >> /home/${USERNAME}/.bashrc \
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
# エントリポイント（起動時に shared volume のパーミッション修正＋認証チェック）
# ---------------------------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} entrypoint.sh /home/${USERNAME}/.local/bin/entrypoint.sh
RUN chmod +x /home/${USERNAME}/.local/bin/entrypoint.sh

WORKDIR /home/${USERNAME}/project

ENTRYPOINT ["/home/coder/.local/bin/entrypoint.sh"]
CMD ["bash"]
