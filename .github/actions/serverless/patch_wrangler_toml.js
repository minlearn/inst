const fs = require('fs');
const path = require('path');
const toml = require('toml');
const {WranglerCmd, VarsReader} = require('./lib/cfutils');

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

// 从 env 读取需要同步到部署的敏感/鉴权变量（未设置时跳过同步）。
// 优先取 process.env（CI workflow env 注入）；因为本脚本常被 sudo 调用且 process.env 可能被清空，
// 回退到 .vars.toml（由 generate_vars_toml.sh 生成，VarsReader 按 DEPLOYMENT_ENVIRONMENT 读取）。
const _varsReader = (() => {
  try {
    return new VarsReader(process.env.DEPLOYMENT_ENVIRONMENT || 'development');
  } catch (e) {
    return null;
  }
})();

function envValue(key) {
  const fromProc = process.env[key];
  if (fromProc !== undefined && fromProc !== null && String(fromProc).trim() !== '') {
    return fromProc;
  }
  if (_varsReader) {
    const fromToml = _varsReader.get(key);
    if (fromToml !== undefined && fromToml !== null && String(fromToml).trim() !== '') {
      return fromToml;
    }
  }
  return undefined;
}

const syncVars = {
  CF_CREDENTIALS_KEY: envValue('CF_CREDENTIALS_KEY'),
  ADMIN_API_TOKEN: envValue('ADMIN_API_TOKEN'),
};

function fmtVar(v) {
  return `"${String(v).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

// 把 syncVars 写回 wrangler.toml 的 [vars] 段：更新已存在的键，缺失的键在段首补入。
function patchVarsSection(tomlText) {
  const entries = Object.entries(syncVars).filter(
    ([, v]) => v !== undefined && v !== null && String(v).trim() !== ''
  );
  if (!entries.length) {
    console.log('[patch_wrangler_toml] 未从 env 取到 CF_CREDENTIALS_KEY / ADMIN_API_TOKEN，跳过 vars patch');
    return tomlText;
  }
  console.log(`[patch_wrangler_toml] 将从 env 同步 vars: ${Object.keys(Object.fromEntries(entries)).join(', ')}`);

  const lines = tomlText.split('\n');
  const pending = new Map(entries);
  let headerIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*\[vars\]\s*$/.test(lines[i])) {
      headerIdx = i;
      break;
    }
  }

  if (headerIdx === -1) {
    const extra = entries.map(([k, v]) => `${k} = ${fmtVar(v)}`);
    return `${tomlText.replace(/\s*$/, '')}\n\n[vars]\n${extra.join('\n')}\n`;
  }

  let bodyEnd = lines.length;
  for (let i = headerIdx + 1; i < lines.length; i++) {
    if (/^\s*\[/.test(lines[i].trim())) {
      bodyEnd = i;
      break;
    }
  }

  for (let i = headerIdx + 1; i < bodyEnd; i++) {
    const trimmed = lines[i].trim();
    for (const [k, v] of pending) {
      if (new RegExp(`^${k}\\s*=`).test(trimmed)) {
        const indent = lines[i].slice(0, lines[i].length - lines[i].trimStart().length);
        lines[i] = `${indent}${k} = ${fmtVar(v)}`;
        pending.delete(k);
        break;
      }
    }
  }

  if (pending.size) {
    const inserts = [...pending].map(([k, v]) => `${k} = ${fmtVar(v)}`);
    lines.splice(headerIdx + 1, 0, ...inserts);
  }

  return lines.join('\n');
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
  let tomlContent = out.join('[[d1_databases]]');
  tomlContent = patchVarsSection(tomlContent);
  fs.writeFileSync(wranglerToml, tomlContent);
  console.log(`[patch_wrangler_toml] 已完成 patch: ${wranglerToml}`);
})();