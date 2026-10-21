# Use in CI
if test -f ".vars.toml"; then
    echo ".vars.toml exists."
    exit
fi

cat << EOF > .vars.toml
          CLOUDFLARE_PROJECT_NAME = "$CLOUDFLARE_PROJECT_NAME"
          CLOUDFLARE_ACCOUNT_ID = "$CLOUDFLARE_ACCOUNT_ID"
          CLOUDFLARE_API_TOKEN = "$CLOUDFLARE_API_TOKEN"

          PRODUCTION_BRANCH = "$PRODUCTION_BRANCH"

          APP_VERSION = "v1"
          NODE_VERSION = "17.0"

          DEPLOYMENT_ENVIRONMENT = "$DEPLOYMENT_ENVIRONMENT"
EOF
