# GitHubアカウント名修正プラン

## Context

GitHubアカウントに再ログインした結果、LICENSEファイルの著作権者名が古い `yok-tottii` のままであることが判明。現在のGitHubアカウント名 `YokTotti` に合わせて修正する。

---

## 対応項目

- [ ] `LICENSE` ファイルの著作権者名を `yok-tottii` → `YokTotti` に変更

## 対象ファイル

| 操作 | ファイルパス | 変更内容 |
|------|-------------|----------|
| 修正 | `LICENSE` | `Copyright (c) 2026 yok-tottii` → `Copyright (c) 2026 YokTotti` |

## 検証方法

1. `grep 'Copyright' LICENSE` で著作権者名が `YokTotti` になっていることを確認
