-- 装机（instrepos）网络源管理：多源缓存模式
CREATE TABLE IF NOT EXISTS instrepos_sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url TEXT NOT NULL,
  name TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_synced TEXT,
  last_status TEXT NOT NULL DEFAULT 'unknown',
  last_error TEXT,
  etag TEXT,
  cached_catalog TEXT,
  cached_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- PVE 应用商店（pveapps）网络源管理：对齐 instrepos_sources 的多源缓存模式
CREATE TABLE IF NOT EXISTS pveapps_sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url TEXT NOT NULL,
  name TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_synced TEXT,
  last_status TEXT NOT NULL DEFAULT 'unknown',
  last_error TEXT,
  etag TEXT,
  cached_catalog TEXT,
  cached_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 模板商店（cfstore）网络源管理：对齐 instrepos_sources / pveapps_sources 的多源缓存模式
CREATE TABLE IF NOT EXISTS cfstore_sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url TEXT NOT NULL,
  name TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_synced TEXT,
  last_status TEXT NOT NULL DEFAULT 'unknown',
  last_error TEXT,
  etag TEXT,
  cached_catalog TEXT,
  cached_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
-- ============================================================
-- 种子数据：默认源（内置装机源 / 内置 PVE 应用源 / 内置模板源）
-- 幂等：WHERE NOT EXISTS 避免重复执行时重复插入。
-- ============================================================
-- 内置装机源：新格式 repos 数组，对齐pveapps/cf-store，只含内置（dummy/custom）,数据由 instrepos.ts 固化生成，这里直接整份写进数据库（无需联网拉取）
INSERT INTO instrepos_sources (url, name, is_default, enabled, last_status, cached_catalog, cached_at, created_at)
SELECT 'builtin://instrepos', '内置装机源', 1, 1, 'ok', '[{"id":"default","title":"default","icon":"svg:linux","entries":[{"system":"dummy","icon":"svg:linux","author":"builtin","size":"—","platform":"amd64","boot":"BIOS/UEFI","password":"dummy","url":"dummy"},{"system":"__custom__","icon":"svg:linux","author":"builtin","size":"—","platform":"amd64","boot":"BIOS/UEFI","password":"inst.sh","url":"__custom__"}]}]', datetime('now'), datetime('now')
WHERE NOT EXISTS (SELECT 1 FROM instrepos_sources WHERE url = 'builtin://instrepos');

-- 默认外置装机源（首次同步后才有 cached_catalog）
INSERT INTO instrepos_sources (url, name, is_default, enabled, last_status, cached_catalog, cached_at, created_at)
SELECT 'https://github.com/minlearn/instapps/releases/download/inital/instrepos.json', 'instrepos 远程默认源', 0, 1, 'unknown', NULL, NULL, datetime('now')
WHERE NOT EXISTS (SELECT 1 FROM instrepos_sources WHERE url = 'https://github.com/minlearn/instapps/releases/download/inital/instrepos.json');

-- 内置 PVE 应用商店源：数据由 pveapps.ts 固化生成，这里直接整份写进数据库（无需联网拉取）
-- cached_catalog 为明文 apps 数组 JSON；其中 installSh 字段为 base64 编码的 install.sh 全文，运行时由服务层解码。
INSERT INTO pveapps_sources (url, name, is_default, enabled, last_status, cached_catalog, cached_at, created_at)
SELECT 'builtin://pveapps', '内置 PVE 应用源', 1, 1, 'ok', '[{"slug":"template","name":"template","version":"1.0.0","icon":"lucide:package","rid":"default","tags":["template","base"],"description":"基础模板容器：内置 install.sh，安装 curl/sudo/mc 等基础依赖，可作为其它应用的地基。","conf":{"unprivileged":0},"installSh":"IyMjIyMjIyMjIyMjIyMjCnNpbGVudCgpIHsgIiRAIiA+L2Rldi9udWxsIDI+JjEgfHwgeyBlY2hvICJFcnJvciBydW5uaW5nOiAkKiI7IGVjaG8gInN0aCBlcnJvciI7IGV4aXQgMTsgfTsgfQpkZWJtaXJyb3I9JHsxOi1odHRwOi8vYXJjaGl2ZS5kZWJpYW4ub3JnL2RlYmlhbn0KZWNobyAtZSAiZGViICR7ZGVibWlycm9yfSBidWxsc2V5ZSBtYWluXG5kZWIgJHtkZWJtaXJyb3J9IGJ1bGxzZXllLXVwZGF0ZXMgbWFpbiIgPiAvZXRjL2FwdC9zb3VyY2VzLmxpc3QgIyBcbmRlYiAke2RlYm1pcnJvcn0tc2VjdXJpdHkgYnVsbHNleWUtc2VjdXJpdHkgbWFpbgplY2hvICJJbnN0YWxsaW5nIERlcGVuZGVuY2llcyIKc2lsZW50IGFwdC1nZXQgdXBkYXRlIC15CnNpbGVudCBhcHQtZ2V0IGluc3RhbGwgLXkgY3VybCBzdWRvIG1jCmVjaG8gIkluc3RhbGxlZCBEZXBlbmRlbmNpZXMiCmVjaG8gIkNsZWFuaW5nIHVwIgpzaWxlbnQgYXB0LWdldCAteSBhdXRvcmVtb3ZlCnNpbGVudCBhcHQtZ2V0IC15IGF1dG9jbGVhbgplY2hvICJDbGVhbmVkIgojIyMjIyMjIyMjIyMjIw=="}]', datetime('now'), datetime('now')
WHERE NOT EXISTS (SELECT 1 FROM pveapps_sources WHERE url = 'builtin://pveapps');

-- 默认外置 PVE 应用源（首次同步后才有 cached_catalog）
INSERT INTO pveapps_sources (url, name, is_default, enabled, last_status, cached_catalog, cached_at, created_at)
SELECT 'https://github.com/minlearn/instapps/releases/download/inital/pveapps.json', 'pveapps 远程默认源', 0, 1, 'unknown', NULL, NULL, datetime('now')
WHERE NOT EXISTS (SELECT 1 FROM pveapps_sources WHERE url = 'https://github.com/minlearn/instapps/releases/download/inital/pveapps.json');

-- 内置 cfstore 模板源：数据由 catalog.ts 固化生成，这里直接整份写进数据库（无需联网拉取）
INSERT INTO cfstore_sources (url, name, is_default, enabled, last_status, cached_catalog, cached_at, created_at)
SELECT 'builtin://cfstore', '默认目录', 1, 1, 'ok', '{"version":"1.0.0","name":"模板商店","description":"内置模板：直接挑选并部署到任意已接入的 Cloudflare 账户。","templates":[{"id":"hello-worker","name":"Hello Worker","icon":"lucide:file-code","description":"最小的 Cloudflare Worker：返回问候语、部署时间和可选的环境变量问候。","version":"1.0.0","type":"worker","tags":["worker","hello","入门"],"rid":"default","author":{"name":"Supportly"},"script":"export default {\n  async fetch(request, env, ctx) {\n    const greeting = env.GREETING || \"Hello\";\n    const now = new Date().toISOString();\n    return new Response(`${greeting}, from Cloudflare at ${now}\\n`, {\n      headers: { \"Content-Type\": \"text/plain; charset=utf-8\", \"Access-Control-Allow-Origin\": \"*\" }\n    });\n  }\n};","compatibilityDate":"2024-11-01","vars":[{"name":"GREETING","label":"问候语","type":"plain_text","defaultValue":"你好"}]}]}', datetime('now'), datetime('now')
WHERE NOT EXISTS (SELECT 1 FROM cfstore_sources WHERE url = 'builtin://cfstore');