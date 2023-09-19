"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
const core_1 = require("@actions/core");
const os_1 = require("os");
const PowerShellSshClient_1 = require("./PowerShellSshClient");
function main() {
    return __awaiter(this, void 0, void 0, function* () {
        (0, core_1.startGroup)("Hyper-V action general information");
        console.log(`Starting the HyperV action on Hyper-V host ${os_1.hostname} using the plattform ${(0, os_1.platform)()}`);
        var isSshModeEnabledString = (0, core_1.getInput)("SSHMode", { required: false, trimWhitespace: true });
        var isSshModeEnabled = getBoolean(isSshModeEnabledString);
        if (!isSshModeEnabled) {
            console.log("SSH mode is not enabled. Using PowerShell remote protocol.");
            yield executeInPowerShellRemoteMode();
        }
        else {
            console.log("SSH mode is enabled. Using SSH protocol.");
            yield executeInSSHMode();
        }
    });
}
function executeInPowerShellRemoteMode() {
    return __awaiter(this, void 0, void 0, function* () {
        var isWin = process.platform === "win32";
        if (isWin) {
            console.log("Starting executing PowerShell commands.");
            var hyperVCmd = String.prototype.concat(".\\ps\\HyperVServer.ps1");
            hyperVCmd += String.prototype.concat(createHyperVScriptCommand());
            (0, core_1.endGroup)();
            const pwshHyperV = (0, child_process_1.spawn)("powershell.exe", [hyperVCmd], {
                stdio: "inherit",
            });
            yield new Promise((resolve) => {
                pwshHyperV.on("close", (code) => {
                    console.log(`PowerShell process exited with code ${code}`);
                    if (code != 0) {
                        (0, core_1.setFailed)(`PowerShell process exited with code ${code}`);
                    }
                    resolve();
                });
            });
            console.log("### DONE");
        }
        else {
            console.error("Connecting via PowerShell remote protocol is only supported on Windows. Please enable SSH mode.");
        }
    });
}
function createHyperVScriptCommand() {
    var action = (0, core_1.getInput)("Command", { required: true, trimWhitespace: true });
    var vmName = (0, core_1.getInput)("VMName", { required: true, trimWhitespace: true });
    var computername = (0, core_1.getInput)("Hostname", {
        required: true,
        trimWhitespace: true,
    });
    var CheckpointName = (0, core_1.getInput)("CheckpointName", {
        required: false,
        trimWhitespace: true,
    });
    var StartVMWaitTimeBasedCheckInterval = (0, core_1.getInput)("StartVMWaitTimeBasedCheckInterval", { required: false, trimWhitespace: true });
    var StartVMStatusCheckType = (0, core_1.getInput)("StartVMStatusCheckType", {
        required: false,
        trimWhitespace: true,
    });
    var HyperV_StartVMWaitingNumberOfStatusNotifications = (0, core_1.getInput)("HyperV_StartVMWaitingNumberOfStatusNotifications", { required: false, trimWhitespace: true });
    var HyperV_StartVMAppHealthyHeartbeatTimeout = (0, core_1.getInput)("HyperV_StartVMAppHealthyHeartbeatTimeout", { required: false, trimWhitespace: true });
    var HyperV_PsModuleVersion = (0, core_1.getInput)("HyperV_PsModuleVersion", {
        required: false,
        trimWhitespace: true,
    });
    var optionalParameters = "";
    if (!isEmpty(CheckpointName)) {
        optionalParameters += String.prototype.concat(" ", "-CheckpointName", " ", CheckpointName);
    }
    if (!isEmpty(StartVMWaitTimeBasedCheckInterval)) {
        optionalParameters += String.prototype.concat(" ", "-StartVMWaitTimeBasedCheckInterval", " ", StartVMWaitTimeBasedCheckInterval);
    }
    if (!isEmpty(StartVMStatusCheckType)) {
        optionalParameters += String.prototype.concat(" ", "-StartVMStatusCheckType", " ", StartVMStatusCheckType);
    }
    if (!isEmpty(HyperV_StartVMWaitingNumberOfStatusNotifications)) {
        optionalParameters += String.prototype.concat(" ", "-HyperV_StartVMWaitingNumberOfStatusNotifications", " ", HyperV_StartVMWaitingNumberOfStatusNotifications);
    }
    if (!isEmpty(HyperV_StartVMAppHealthyHeartbeatTimeout)) {
        optionalParameters += String.prototype.concat(" ", "-HyperV_StartVMAppHealthyHeartbeatTimeout", " ", HyperV_StartVMAppHealthyHeartbeatTimeout);
    }
    if (!isEmpty(HyperV_PsModuleVersion)) {
        optionalParameters += String.prototype.concat(" ", "-HyperV_PsModuleVersion", " ", HyperV_PsModuleVersion);
    }
    var hyperVCmd = String.prototype.concat(" ", "-ComputerName", " ", computername);
    hyperVCmd += String.prototype.concat(" ", "-Action", " ", action);
    hyperVCmd += String.prototype.concat(" ", "-VMName", " ", vmName);
    hyperVCmd += String.prototype.concat(optionalParameters);
    (0, core_1.debug)("### HyperV command script parameter: " + hyperVCmd);
    return hyperVCmd;
}
function executeInSSHMode() {
    return __awaiter(this, void 0, void 0, function* () {
        var sshPrivatekey = (0, core_1.getInput)("SSHPrivateKey", { required: false, trimWhitespace: true });
        var sshHost = (0, core_1.getInput)("SSHHostName", { required: true, trimWhitespace: true });
        var sshUsername = (0, core_1.getInput)("SSHUsername", { required: true, trimWhitespace: true });
        var sshPort = Number.parseInt((0, core_1.getInput)("SSHPort", { required: true, trimWhitespace: true }));
        var ssh = null;
        if (isEmpty(sshPrivatekey)) {
            console.log("### Connecting via SSH with username and password");
            var sshPassword = (0, core_1.getInput)("SSHPassword", { required: true, trimWhitespace: true });
            if (isEmpty(sshPassword)) {
                console.error("SSH password is required if no private key is provided.");
            }
            ssh = new PowerShellSshClient_1.PowerShellSSHClient({
                host: sshHost,
                port: sshPort,
                username: sshUsername,
                password: sshPassword,
            });
        }
        else {
            console.log("### Connecting via SSH with private key");
            ssh = new PowerShellSshClient_1.PowerShellSSHClient({
                host: sshHost,
                port: sshPort,
                username: sshUsername,
                privateKey: sshPrivatekey,
            });
        }
        var scriptArguments = createHyperVScriptCommand();
        (0, core_1.endGroup)();
        try {
            var result = yield ssh.executeScript('./ps/HyperVServer.ps1', scriptArguments);
            result = result.trim();
            (0, core_1.debug)("### Result: " + result);
            console.log("### Done");
        }
        catch (error) {
            if (error instanceof Error) {
                (0, core_1.setFailed)(error.message);
            }
            else {
                (0, core_1.setFailed)("An unknown error occurred. Please check the logs. Error message:" + error);
                throw error;
            }
        }
    });
}
function isEmpty(value) {
    return ((typeof value == "string" && !value.trim()) ||
        typeof value == "undefined" ||
        value === null);
}
function getBoolean(value) {
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
//# sourceMappingURL=index.js.map