const {exec} = require('child_process');
const {WranglerCmd} = require("./lib/cfutils");

const cmd = new WranglerCmd(process.env.DEPLOYMENT_ENVIRONMENT || 'development');
exec(cmd.createAppDb(), (error, stdout, stderr) => {
  if (error) {
    console.log(`error: ${error.message}`);
  }
  if (stderr) {
    console.log(`stderr: ${stderr}`);
  }
  if (stdout) {
    console.log(`stdout: ${stdout}`);
  }
  //exec(cmd.createAppDbTables(), (error, stdout, stderr) => {
  //  if (error) {
  //    console.log(`error: ${error.message}`);
  //  }
  //  if (stderr) {
  //    console.log(`stderr: ${stderr}`);
  //  }
  //  if (stdout) {
  //    console.log(`stdout: ${stdout}`);
  //  }
  //});
});
