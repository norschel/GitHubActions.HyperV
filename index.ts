import { spawn } from "child_process";
import { getInput, setFailed } from "@actions/core";
import { hostname, platform } from "os";
import { PowerShellSSHClient } from "./PowerShellSshClient";

async function main() {
  // https://stackoverflow.com/questions/8683895/how-do-i-determine-the-current-operating-system-with-node-js

  console.log(`Starting the HyperV action on Hyper-V host ${hostname} using the plattform ${platform()}`);
  var isSshModeEnabledString = getInput("SSHMode", { required: false, trimWhitespace: true });
  var isSshModeEnabled = getBoolean(isSshModeEnabledString);

  // we check if ssh mode is enabled
  // if it is enabled, we will use ssh to execute the commands on the remote machine
  // ssh works on all platforms (Windows, Mac, Linux)

  // if ssh mode is not enabled, we will use PowerShell to execute the commands on the remote machine
  // PowerShell works only on Windows
  if (!isSshModeEnabled) {
    console.log("SSH mode is not enabled. Using PowerShell remote protocol.");
    await executeInPowerShellRemoteMode();
  }
  else {
    console.log("SSH mode is enabled. Using SSH protocol.");
    // ssh mode is enabled
    await executeInSSHMode();
  }
}

async function executeInPowerShellRemoteMode() {
  var isWin = process.platform === "win32";

  if (isWin) {
    // Executing using powershell shell
    console.log("Starting executing PowerShell commands.");
    // https://www.freecodecamp.org/news/node-js-child-processes-everything-you-need-to-know-e69498fe970a/
    // https://nodejs.org/api/child_process.html
    // https://2ality.com/2018/05/child-process-streams.html
    // https://www.npmjs.com/package/@rauschma/stringio
    //var childProcess = execSync("write-host $env:path; get-vm", {
    //  shell: "powershell.exe",
    //});
    //console.log(childProcess.toLocaleString());
    var hyperVCmd = String.prototype.concat(".\\ps\\HyperVServer.ps1");
    hyperVCmd += String.prototype.concat(createHyperVScriptCommand());

    const pwshHyperV = spawn("powershell.exe", [hyperVCmd], {
      stdio: "inherit",
    });

    await new Promise<void>((resolve) => {
      pwshHyperV.on("close", (code) => {
        console.log(`PowerShell process exited with code ${code}`);
        if (code != 0) {
          setFailed(`PowerShell process exited with code ${code}`);
        }
        resolve();
      })
    });

    console.log("### DONE");
  }
  else {
    console.error("Connecting via PowerShell remote protocol is only supported on Windows. Please enable SSH mode.");
  }
}

function createHyperVScriptCommand() {
  var action = getInput("Command", { required: true, trimWhitespace: true });
  var vmName = getInput("VMName", { required: true, trimWhitespace: true });
  var computername = getInput("Hostname", {
    required: true,
    trimWhitespace: true,
  });
  var CheckpointName = getInput("CheckpointName", {
    required: false,
    trimWhitespace: true,
  });
  var StartVMWaitTimeBasedCheckInterval = getInput(
    "StartVMWaitTimeBasedCheckInterval",
    { required: false, trimWhitespace: true }
  );
  var StartVMStatusCheckType = getInput("StartVMStatusCheckType", {
    required: false,
    trimWhitespace: true,
  });
  var HyperV_StartVMWaitingNumberOfStatusNotifications = getInput(
    "HyperV_StartVMWaitingNumberOfStatusNotifications",
    { required: false, trimWhitespace: true }
  );
  var HyperV_StartVMAppHealthyHeartbeatTimeout = getInput(
    "HyperV_StartVMAppHealthyHeartbeatTimeout",
    { required: false, trimWhitespace: true }
  );
  var HyperV_PsModuleVersion = getInput("HyperV_PsModuleVersion", {
    required: false,
    trimWhitespace: true,
  });

  var optionalParameters = "";
  if (!isEmpty(CheckpointName)) {
    optionalParameters += String.prototype.concat(
      " ",
      "-CheckpointName",
      " ",
      CheckpointName
    );
  }

  if (!isEmpty(StartVMWaitTimeBasedCheckInterval)) {
    optionalParameters += String.prototype.concat(
      " ",
      "-StartVMWaitTimeBasedCheckInterval",
      " ",
      StartVMWaitTimeBasedCheckInterval
    );
  }

  if (!isEmpty(StartVMStatusCheckType)) {
    optionalParameters += String.prototype.concat(
      " ",
      "-StartVMStatusCheckType",
      " ",
      StartVMStatusCheckType
    );
  }

  if (!isEmpty(HyperV_StartVMWaitingNumberOfStatusNotifications)) {
    optionalParameters += String.prototype.concat(
      " ",
      "-HyperV_StartVMWaitingNumberOfStatusNotifications",
      " ",
      HyperV_StartVMWaitingNumberOfStatusNotifications
    );
  }

  if (!isEmpty(HyperV_StartVMAppHealthyHeartbeatTimeout)) {
    optionalParameters += String.prototype.concat(
      " ",
      "-HyperV_StartVMAppHealthyHeartbeatTimeout",
      " ",
      HyperV_StartVMAppHealthyHeartbeatTimeout
    );
  }

  if (!isEmpty(HyperV_PsModuleVersion)) {
    optionalParameters += String.prototype.concat(
      " ",
      "-HyperV_PsModuleVersion",
      " ",
      HyperV_PsModuleVersion
    );
  }

  var hyperVCmd = String.prototype.concat(" ", "-ComputerName", " ", computername);
  hyperVCmd += String.prototype.concat(" ", "-Action", " ", action);
  hyperVCmd += String.prototype.concat(" ", "-VMName", " ", vmName);
  hyperVCmd += String.prototype.concat(optionalParameters);
  return hyperVCmd;
}

async function executeInSSHMode() {
  var sshPrivatekey = getInput("SSHPrivateKey", { required: false, trimWhitespace: true });
  var sshHost = getInput("SSHHostName", { required: true, trimWhitespace: true });
  var sshUsername = getInput("SSHUsername", { required: true, trimWhitespace: true });
  var sshPort = Number.parseInt(getInput("SSHPort", { required: true, trimWhitespace: true }));

  // we use username and password if private key is not provided (default)
  var ssh = null;
  if (isEmpty(sshPrivatekey)) {
    console.log("### Connecting via SSH with username and password");

    var sshPassword = getInput("SSHPassword", { required: true, trimWhitespace: true });
    if (isEmpty(sshPassword)) {
      console.error("SSH password is required if no private key is provided.");
    }

    ssh = new PowerShellSSHClient({
      host: sshHost,
      port: sshPort,
      username: sshUsername,
      password: sshPassword,
    });
  }
  else {
    console.log("### Connecting via SSH with private key");
    ssh = new PowerShellSSHClient({
      host: sshHost,
      port: sshPort,
      username: sshUsername,
      privateKey: sshPrivatekey,
    });
  }

  var scriptArguments = createHyperVScriptCommand();
  console.log("### Script arguments: " + scriptArguments);
  try {
    var result = await ssh.executeScript('./ps/HyperVServer.ps1', scriptArguments);
    result = result.trim();
    //only used for testing
    //console.log("### Result: " + result);
    console.log("### Done");
  }
  catch (error) {
    if (error instanceof Error) {
      setFailed(error.message);
    } else {
      setFailed("An unknown error occurred. Please check the logs. Error message:" + error);
      throw error;
    }
  }
}


//source: https://stackoverflow.com/questions/1812245/what-is-the-best-way-to-test-for-an-empty-string-with-jquery-out-of-the-box
function isEmpty(value: string | null): boolean {
  return (
    (typeof value == "string" && !value.trim()) ||
    typeof value == "undefined" ||
    value === null
  );
}

function getBoolean(value: any): boolean {
  value = value.toLowerCase().trim();
  switch (value) {
    case true:
    case "true":
    case 1:
    case "1":
    case "on":
    case "yes":
      return true;
    default:
      return false;
  }
}

if (require.main === module) {
  main();
}
