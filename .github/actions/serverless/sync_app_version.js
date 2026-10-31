const {exec} = require('child_process');

const {APP_VERSION} = require('./version');

exec(`yarn version ${APP_VERSION}`, (error, stdout, stderr) => {
  if (error) {
    console.log(error);
    console.log('exit.');
  } else {
    if (stdout) {
      console.log(`stdout - \n${stdout}`);
    }
    if (stderr) {
      console.log(`stderr - \n${stderr}`);
    }
    console.log(`Updated package.json version to ${APP_VERSION}.`);
  }
});
