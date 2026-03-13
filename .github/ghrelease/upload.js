const { Octokit } = require("@octokit/rest");
const fs = require("fs");
const path = require("path");

const GH_TOKEN = process.env.GH_PAT; // 你的高权限 PAT
const OWNER = "minlearn";
const REPO = "discuss";
const TAG = "inital";
const LOCAL_DIR = "_tmpbuild/apps"; // 如 "./apps"

const octokit = new Octokit({ auth: GH_TOKEN });

async function getOrCreateRelease() {
  let release;
  try {
    release = await octokit.repos.getReleaseByTag({
      owner: OWNER,
      repo: REPO,
      tag: TAG
    });
    console.log("Release exists:", release.data.html_url);
  } catch (e) {
    if (e.status === 404) {
      release = await octokit.repos.createRelease({
        owner: OWNER,
        repo: REPO,
        tag_name: TAG,
        name: TAG,
        body: "Auto-created initial release"
      });
      console.log("Created new release:", release.data.html_url);
    } else {
      throw e;
    }
  }
  return release.data;
}

async function getExistingAssets(release) {
  const assets = await octokit.repos.listReleaseAssets({
    owner: OWNER,
    repo: REPO,
    release_id: release.id,
  });
  return assets.data;
}

async function deleteAsset(assetId, name) {
  await octokit.repos.deleteReleaseAsset({
    owner: OWNER,
    repo: REPO,
    asset_id: assetId,
  });
  console.log(`Deleted existing asset: ${name}`);
}

async function uploadAssetsToRelease(release, localDir) {
  const files = fs.readdirSync(localDir);
  const existingAssets = await getExistingAssets(release);

  for (const file of files) {
    const filePath = path.join(localDir, file);
    const stats = fs.statSync(filePath);
    if (!stats.isFile()) continue;

    // 检查是否存在同名 asset
    const existing = existingAssets.find(a => a.name === file);
    if (existing) {
      await deleteAsset(existing.id, file);
    }

    // 上传
    const data = fs.readFileSync(filePath);
    await octokit.repos.uploadReleaseAsset({
      url: release.upload_url,
      headers: {
        "content-type": "application/octet-stream",
        "content-length": data.length,
      },
      name: file,
      data: data,
    });
    console.log(`Uploaded ${file} to release ${TAG}`);
  }
}

(async () => {
  try {
    const release = await getOrCreateRelease();
    await uploadAssetsToRelease(release, LOCAL_DIR);
    console.log("All assets uploaded (with overwrite logic).");
  } catch (e) {
    console.error("Error:", e);
    process.exit(1);
  }
})();