-- =============================================================================
-- PostgreSQL 初期化スクリプト
-- Web 開発コンテナ用のデフォルトデータベースとユーザーを作成
-- =============================================================================

-- 開発用データベース
CREATE DATABASE app_development;
CREATE DATABASE app_test;

-- 拡張機能（よく使うもの）
\c app_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c app_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
