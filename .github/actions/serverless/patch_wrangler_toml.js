const fs = require('fs');
const path = require('path');
const toml = require('toml');
const {WranglerCmd} = require('./lib/cfutils');

// Worker 部署前把 wrangler.toml 的 [[d1_databases]] database_id patch 成真实 D1 uuid。
// 建库由调用方 init_app_db.js 完成；本脚本「不建库」，只查已建库的 uuid 并写回 database_id。
const wranglerToml = path.join(process.env.WORKER_DIR || '_build/www', 'wrangler.toml');

function hasD1Sections() {
  const content = fs.readFileSync(wranglerToml, 'utf-8');
  try {
    const data = toml.parse(content);
    return !!(data.d1_databases && data.d1_databases.length);
  } catch (e) {
    return /\[\[d1_databases\]\]/.test(content);
  }
}

(async () => {
  if (!fs.existsSync(wranglerToml)) {
    console.error(`[patch_wrangler_toml] 未找到 wrangler.toml: ${wranglerToml}`);
    process.exit(1);
  }
  if (!hasD1Sections()) {
    console.log('[patch_wrangler_toml] wrangler.toml 未声明 d1_databases，跳过');
    process.exit(0);
  }

  // 与 init_app_db.js 相同的 currentEnv，查询的是同一个库（getDatabaseId 默认按 ${CLOUDFLARE_PROJECT_NAME}-db 查）
  const cmd = new WranglerCmd(process.env.DEPLOYMENT_ENVIRONMENT || 'development');
  const uuid = await new Promise((resolve) => cmd.getDatabaseId((id) => resolve(id)));
  console.log(`[patch_wrangler_toml] 库 uuid=${uuid || '(未找到)'}${uuid ? '' : ' ← 请确认 init_app_db.js 已建库'}`);
  if (!uuid) process.exit(1);

  // 把所有 [[d1_databases]] 段的 database_id 写为该 uuid
  const sections = fs.readFileSync(wranglerToml, 'utf-8').split(/\[\[d1_databases\]\]/);
  const out = [sections[0]];
  for (let i = 1; i < sections.length; i++) {
    let sec = sections[i];
    if (/database_id\s*=/.test(sec)) {
      sec = sec.replace(/(database_id\s*=\s*)"[^"]*"/, `$1"${uuid}"`);
    } else {
      sec = `database_id = "${uuid}"\n` + sec;
    }
    out.push(sec);
  }
  fs.writeFileSync(wranglerToml, out.join('[[d1_databases]]'));
  console.log(`[patch_wrangler_toml] 已完成 patch: ${wranglerToml}`);
})();