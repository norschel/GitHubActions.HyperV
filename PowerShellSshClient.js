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
exports.PowerShellSSHClient = void 0;
const ssh2_1 = require("ssh2");
class PowerShellSSHClient {
    constructor(config) {
        this.config = config;
        this.client = new ssh2_1.Client();
    }
    executeScript(scriptPath, scriptArguments) {
        return __awaiter(this, void 0, void 0, function* () {
            console.log("### SSH Tunnel - Executing script:" + scriptPath);
            const conn = yield this.connect();
            console.log("### SSH Tunnel - Retrieving remote temp folder");
            var remoteTempFolder = yield this.sendCommand('echo %temp%', conn);
            remoteTempFolder = remoteTempFolder.trim();
            console.log("### SSH Tunnel - Remote temp folder: " + remoteTempFolder);
            var remoteScriptPath = String.prototype.concat(remoteTempFolder, '\\HyperVServer.ps1');
            console.log("### SSH Tunnel - Remote script path: " + remoteScriptPath);
            yield this.uploadFile(conn, scriptPath, remoteScriptPath);
            var result = yield this.sendCommand(`powershell -Command "${remoteScriptPath} ${scriptArguments}"`, conn);
            result = result.trim();
            yield this.disconnect(conn);
            console.log("### SSH Tunnel - Script executed");
            return result;
        });
    }
    connect() {
        return __awaiter(this, void 0, void 0, function* () {
            return new Promise((resolve, reject) => {
                this.client
                    .on('ready', () => {
                    console.log("### SSH Tunnel - Connection ready");
                    resolve(this.client);
                })
                    .on('error', (err) => {
                    console.log("### SSH Tunnel - Connection error");
                    console.log(err);
                    reject(err);
                })
                    .connect(this.config);
                console.log("### SSH Tunnel - Connected");
            });
        });
    }
    uploadFile(conn, localPath, remotePath) {
        return __awaiter(this, void 0, void 0, function* () {
            yield new Promise((resolve, reject) => {
                conn.sftp((err, sftp) => {
                    console.log("### SSH Tunnel - Initiating SFTP connection");
                    if (err) {
                        console.log("### SSH Tunnel - SFTP connection error");
                        reject(err);
                    }
                    console.log("### SSH Tunnel - SFTP connection established");
                    console.log("### SSH Tunnel - Uploading file " + localPath + " to " + remotePath);
                    sftp.fastPut(localPath, remotePath, {}, (err) => {
                        if (err) {
                            console.log("### SSH Tunnel - File upload error");
                            reject(err);
                        }
                        console.log("### SSH Tunnel - File uploaded");
                        resolve();
                    });
                });
            });
        });
    }
    sendCommand(command, conn) {
        return __awaiter(this, void 0, void 0, function* () {
            return new Promise((resolve, reject) => {
                console.log("### SSH Tunnel - Trying to execute command: " + command);
                conn.exec(command, (err, stream) => {
                    if (err) {
                        console.log("### SSH Tunnel - Command error");
                        this.disconnect(conn);
                        reject(err);
                    }
                    console.log("### SSH Tunnel - Command executing");
                    var result = '';
                    stream
                        .on('close', (code, signal) => {
                        console.log("### SSH Tunnel - Command executed");
                        if (code != undefined && Number.parseInt(code) !== 0) {
                            console.log("### SSH Tunnel - Error executing command via PowerShell. Exit code: " + code + " Signal: " + signal);
                            reject("Error executing command via PowerShell. Exit code:" + code + " Signal:" + signal);
                        }
                        console.log("### SSH Tunnel - Exit code:" + code + " signal:" + signal);
                        resolve(result);
                    })
                        .on('data', (data) => {
                        result += data.toString().trim();
                        console.log("(SSH-STDIN) " + data.toString().trim());
                    })
                        .stderr.on('data', (data) => {
                        console.log('(SSH-STDERR) ' + data.toString().trim());
                    });
                });
            });
        });
    }
    disconnect(conn) {
        return __awaiter(this, void 0, void 0, function* () {
            return new Promise((resolve, reject) => {
                console.log("### SSH Tunnel - Disconnecting");
                conn.end();
                console.log("### SSH Tunnel - Disconnected");
            });
        });
    }
}
exports.PowerShellSSHClient = PowerShellSSHClient;
//# sourceMappingURL=PowerShellSshClient.js.map