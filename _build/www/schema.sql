-- 模板商店的多 catalog 源管理（对齐 cf-manager 的 catalog_sources 表）
CREATE TABLE IF NOT EXISTS catalog_sources (
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