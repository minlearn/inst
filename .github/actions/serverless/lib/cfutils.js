const fs = require('fs');
const toml = require('toml');
const https = require('https');

class VarsReader {
  constructor(currentEnv, varsFilePath = '.vars.toml') {
    const varsBuffer = fs.readFileSync(varsFilePath);
    this.data = toml.parse(varsBuffer);
    this.currentEnv = currentEnv;
  }

  get(key, defaultValue = null) {
    const envDict = this.data[this.currentEnv] || {};
    return envDict[key] || this.data[key] || defaultValue;
  }

  flattenVars() {
    const varDict = {};
    const keys = Object.keys(this.data).filter((k) => !['production', 'preview', 'development'].includes(k))
    keys.forEach((k) => {
      varDict[k] = this.get(k, '');
    });
    return varDict;
  }
}

/*
  Set CORS rules for a bucket, so we can use presigned_url to upload files from browser js.
 */
const AWS = require('aws-sdk');

class SetupR2 {
  constructor() {
    const currentEnv = process.env.DEPLOYMENT_ENVIRONMENT || 'production';
    this.v = new VarsReader(currentEnv);
    this.endpoint = `https://${this.v.get('CLOUDFLARE_ACCOUNT_ID')}.r2.cloudflarestorage.com`;
    this.s3 = new AWS.S3({
      region: 'auto',
      signatureVersion: 'v4',
      credentials: new AWS.Credentials(this.v.get('R2_ACCESS_KEY_ID'), this.v.get('R2_SECRET_ACCESS_KEY')),
      endpoint: new AWS.Endpoint(this.endpoint),
    });
  }

  _setupBucket(bucket, onDone) {
    const bucketParams = {
      Bucket: bucket,
      // XXX: Not implemented yet on Cloudflare side - https://developers.cloudflare.com/r2/data-access/s3-api/api/
      // ACL: 'public-read',
    };

    this.s3.createBucket(bucketParams, function (err, data) {
      if (err) {
        if (err.code === 'BucketAlreadyOwnedByYou') {
          console.log(`Bucket exists: ${bucket}`);
        } else {
          console.log("Error", err);
          process.exit(1);
        }
      } else {
        console.log(`Success: ${bucket} created`, data.Location);
      }
      onDone();
    });
  }

  _setupCorsRules() {
    const params = {
      Bucket: this.v.get('R2_PUBLIC_BUCKET'),
      CORSConfiguration: {
        CORSRules: [{
          AllowedMethods: ['DELETE', 'POST', 'PUT'],
          AllowedOrigins: ['*'],
          AllowedHeaders: ['*'],
        }]
      }
    };

    console.log(`Setting up CORS rules for ${this.v.get('R2_PUBLIC_BUCKET')}...`)
    this.s3.putBucketCors(params, (err, data) => {
      if (err) {
        console.log(err);
        process.exit(1);
      } else {
        console.log('Success!', data);
        console.log(params.CORSConfiguration.CORSRules);
      }
    });
  }

  setupPublicBucket() {
    const bucket = this.v.get('R2_PUBLIC_BUCKET');
    this._setupBucket(bucket, () => {
      this._setupCorsRules();
    });
  }
}

class WranglerCmd {
  constructor(currentEnv) {
    this.currentEnv = currentEnv;
    this.v = new VarsReader(currentEnv);
  }

  _getCmd(wranglerCmd) {
    return `CLOUDFLARE_ACCOUNT_ID=${this.v.get('CLOUDFLARE_ACCOUNT_ID')} ` +
      `CLOUDFLARE_API_TOKEN=${this.v.get('CLOUDFLARE_API_TOKEN')} ` + wranglerCmd;
  }

  publishWorker() {
    // pages=Cloudflare Pages(自己走.vars.toml + sync project config+syncr2+syncdb+public+direct upload)；worker=Cloudflare Workers（wrangler.toml全包，DEPLOY_TYPE走CI环境变量）
    // DEPLOY_TYPE=worker → 用 wrangler.toml 部署到 Cloudflare Workers（支持 D1/DO/KV/vars 绑定）
    // DEPLOY_TYPE/WORKER_DIR/WORKER_NAME 由 CI 环境变量注入，不走 .vars.toml，但需要加入定制wrangler.toml的这个过程
    const projectName = process.env.CLOUDFLARE_PROJECT_NAME || this.v.get('CLOUDFLARE_PROJECT_NAME');
    const extra = projectName ? ` --name ${projectName}` : '';
    const wranglerCmd = `wrangler deploy${extra}`;
    console.log(`[worker] cd _build && ${wranglerCmd}`);
    // 环境变量前缀必须放在 `cd` 之后，才能作用于 wrangler（前缀赋值只影响紧随其后的命令）
    return `cd _build/www && ` + this._getCmd(wranglerCmd);
  }

  publishProject() {
    const projectName = this.v.get('CLOUDFLARE_PROJECT_NAME');
    const productionBranch = this.v.get('PRODUCTION_BRANCH', 'main');

    // Cloudflare Pages direct upload uses branch to decide deployment environment.
    // If we want production, then use production_branch. Otherwise, just something else
    const branch = this.currentEnv === 'production' ? productionBranch : `${productionBranch}-preview`;
    const wranglerCmd = `wrangler pages publish _build --project-name ${projectName} --branch ${branch}`;
    console.log(wranglerCmd);
    return this._getCmd(wranglerCmd);
  }

  _is_dev_db() {
    return `${this.v.get('CLOUDFLARE_PROJECT_NAME')}-db_${this.currentEnv}`;
  }

  createAppDb() {
    const wranglerCmd = this.currentEnv == 'development' ?
      `wrangler d1 create ${this._is_dev_db()}` : `wrangler d1 create ${projName}-db`;
    console.log(wranglerCmd);
    return this._getCmd(wranglerCmd);
  }

  createAppDbTables() {
    const dbName = this.currentEnv == 'development' ? this._is_dev_db() : `${this.v.get('CLOUDFLARE_PROJECT_NAME')}-db`;
    const wranglerCmd = this.currentEnv == 'development' ? `wrangler d1 execute ${dbName} --file _build/www/schema.sql --local` : `wrangler d1 execute ${dbName} --file _build/www/schema.sql --remote`;
    console.log(wranglerCmd);
    return this._getCmd(wranglerCmd);
  }

  /**
   * XXX: We use private api here, which may be changed on the cloudflare end...
   * https://github.com/cloudflare/wrangler2/blob/main/packages/wrangler/src/d1/list.tsx#L34
   */
  getDatabaseId(onSuccess) {
    const dbName = this.currentEnv == 'development' ? this._is_dev_db() : `${this.v.get('CLOUDFLARE_PROJECT_NAME')}-db`;
    const accountId = this.v.get('CLOUDFLARE_ACCOUNT_ID');
    const apiKey = this.v.get('CLOUDFLARE_API_TOKEN');
    const options = {
      host: 'api.cloudflare.com',
      port: '443',
      path: `/client/v4/accounts/${accountId}/d1/database?name=${dbName}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
      },
    };
    const request = https.request(options, (response) => {
      let data = '';
      response.on('data', (chunk) => {
        data = data + chunk.toString();
      });

      response.on('end', () => {
        const body = JSON.parse(data);
        let databaseId = '';
        body.result.forEach((result) => {
          if (result.name === dbName) {
            databaseId = result.uuid;
          }
        });
        onSuccess(databaseId);
      });
    })

    request.on('error', (error) => {
      console.log('An error', error);
      onSuccess('');
    });

    request.end();
  }
}

class InitProject {
  constructor() {
    this.currentEnv = 'production';
    this.v = new VarsReader(this.currentEnv);
  }

  _getCurrentProject(data, onProjectExists, onCreateProject) {

    const options = {
      port: 443,
      hostname: 'api.cloudflare.com',
      path: `/client/v4/accounts/${this.v.get('CLOUDFLARE_ACCOUNT_ID')}/pages/projects/${this.v.get('CLOUDFLARE_PROJECT_NAME')}`,
      headers: {
        'Authorization': `Bearer ${this.v.get('CLOUDFLARE_API_TOKEN')}`,
        'Content-Type': 'application/json',
      },
      method: 'GET',
    };

    https.get(options, (res) => {
      if (res.statusCode === 404) {
        onCreateProject();
        return;
      }
      // console.log('headers:', res.headers);

      let body = '';
      res.on('data', (d) => {
        body += d;
      });
      res.on('end', function () {
        try {
          let json = JSON.parse(body);
          onProjectExists(json);
        } catch (error) {
          console.error(error.message);
          process.exit(1);
        }
      });
    }).on('error', (e) => {
      console.error(e);
    });
  }

  _createProject(data, onSuccess) {
    const options = {
      hostname: 'api.cloudflare.com',
      port: 443,
      path: `/client/v4/accounts/${this.v.get('CLOUDFLARE_ACCOUNT_ID')}/pages/projects/`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.v.get('CLOUDFLARE_API_TOKEN')}`,
        'Content-Type': 'application/json',
        'Content-Length': data.length,
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (d) => {
        body += d;
      });
      res.on("end", () => {
        try {
          let json = JSON.parse(body);
          onSuccess(json);
        } catch (error) {
          console.error(error.message);
          process.exit(1);
        }
      });
    });

    req.on('error', (e) => {
      console.error(e);
      process.exit(1);
    });
    req.write(data)
    req.end();
  }

  run() {
    console.log(`Init project ${this.v.get('CLOUDFLARE_PROJECT_NAME')} [${this.currentEnv}]...`);
    this._getCurrentProject({}, (json) => {
      console.log('got it!');
      console.log(`${this.v.get('CLOUDFLARE_PROJECT_NAME')} exists.`);
      console.log(json);
    }, () => {
      console.log('creating!')
      console.log(`Creating project: ${this.v.get('CLOUDFLARE_PROJECT_NAME')}...`)
      const data = JSON.stringify({
        'subdomain': this.v.get('CLOUDFLARE_PROJECT_NAME'),
        'production_branch': this.v.get('PRODUCTION_BRANCH', 'main'),
        'name': this.v.get('CLOUDFLARE_PROJECT_NAME'),
      });
      this._createProject(data, () => {
        console.log('Project created!')
      });
    });
  }
}

const ALLOWED_VARS = [
  {name: 'CLOUDFLARE_ACCOUNT_ID', encrypted: true, required: true},
  {name: 'CLOUDFLARE_PROJECT_NAME', encrypted: true, required: true},
  {name: 'CLOUDFLARE_API_TOKEN', encrypted: true, required: true},
  {name: 'DEPLOYMENT_ENVIRONMENT', encrypted: false, required: false},

  {name: 'NODE_VERSION', encrypted: false, required: false},  // Cloudflare Pages CI needs this to use the right Node version.
  {name: 'APP_VERSION', encrypted: false, required: false},
];

class SyncProjectConfig {
  constructor() {
    this.currentEnv = process.env.DEPLOYMENT_ENVIRONMENT || 'production';
    this.v = new VarsReader(this.currentEnv);
    this.cmd = new WranglerCmd(process.env.DEPLOYMENT_ENVIRONMENT || 'development');
  }

  _getEnvVarsFromFilesJson(envName, databaseId) {
    // https://api.cloudflare.com/#pages-project-get-projects
    const envVarsJson = {
      [envName]: {
        'env_vars': {
          'DEPLOYMENT_ENVIRONMENT': this.currentEnv,
        },
      },
    };
    if (databaseId) {
      envVarsJson[envName]['d1_databases'] = {
        DB: {
          id: databaseId,
        }
      };
    }
    ALLOWED_VARS.forEach((varDict) => {
      const varValue = this.v.get(varDict.name) || '';
      envVarsJson[envName]['env_vars'][varDict.name] = {
        'value': varValue,
        'type': varDict.encrypted ? 'secret_text' : 'plain_text',
      };
    });
    return envVarsJson;
  }

  _updateEnvVars(data, onSuccess) {
    const options = {
      hostname: 'api.cloudflare.com',
      port: 443,
      path: `/client/v4/accounts/${this.v.get('CLOUDFLARE_ACCOUNT_ID')}/pages/projects/${this.v.get('CLOUDFLARE_PROJECT_NAME')}`,
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${this.v.get('CLOUDFLARE_API_TOKEN')}`,
        'Content-Type': 'application/json',
        'Content-Length': data.length,
      },
    };

    const req = https.request(options, (res) => {
      // console.log('statusCode:', res.statusCode);
      // console.log('headers:', res.headers);
      let body = '';
      res.on('data', (d) => {
        // d.result.deployment_configs.preview
        // d.result.deployment_configs.production
        // process.stdout.write(d);
        // onSuccess(d);
        body += d;
      });
      res.on("end", () => {
        try {
          let json = JSON.parse(body);
          onSuccess(json);
        } catch (error) {
          console.error(error.message);
          process.exit(1);
        }
      });
    });

    req.on('error', (e) => {
      console.error(e);
      process.exit(1);
    });
    req.write(data)
    req.end();
  }

  syncEnvVars() {
    console.log(`Sync-ing for [${this.currentEnv}]...`);

    // ensure that required vars are set
    let missingVars = [];
    ALLOWED_VARS.forEach((varDict) => {
      if (varDict.required && !this.v.get(varDict.name)) {
        missingVars.push(varDict.name);
      }
    });
    if (missingVars.length > 0) {
      console.error(`Missing required vars: ${missingVars.join(', ')}`);
      process.exit(1);
    }
    // ensure that the project name is valid
    if (!this.v.get('CLOUDFLARE_PROJECT_NAME').match(/^[a-zA-Z0-9-]+$/)) {
      console.error(`Invalid project name: ${this.v.get('CLOUDFLARE_PROJECT_NAME')}`);
      process.exit(1);
    }


    this.cmd.getDatabaseId((databaseId) => {
      console.log('Database id (num of chars): ', databaseId.length)
      const varsToAddOrUpdate = JSON.stringify({
        'deployment_configs': {
          ...this._getEnvVarsFromFilesJson(this.currentEnv, databaseId),
        },
      });

      this._updateEnvVars(varsToAddOrUpdate, (json) => {
        console.log(`Successfully synced for [${this.currentEnv}]!`);
        if (json.result && json.result.deployment_configs) {
          console.log(json.result.deployment_configs[this.currentEnv].env_vars);
        } else if (json) {
          console.log(json);
        }
      });
    });
  }
}

module.exports = {
  VarsReader,
  SetupR2,
  WranglerCmd,
  InitProject,
  SyncProjectConfig
};
