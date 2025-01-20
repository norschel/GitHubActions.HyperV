import { Client, ConnectConfig } from 'ssh2';

export class PowerShellSSHClient {
  private readonly client: Client;

  constructor(private readonly config: ConnectConfig, private readonly pwsh: string = "pwsh") {
    this.client = new Client();
  }

  async executeScript(scriptPath: string, scriptArguments: string): Promise<string> {
    console.log("### SSH Tunnel - Executing script:" + scriptPath);
    const conn = await this.connect();
    
    console.log("### SSH Tunnel - Retrieving remote temp folder");
    var remoteTempFolder = await this.sendCommand('echo %temp%', conn);
    remoteTempFolder = remoteTempFolder.trim();
    console.log("### SSH Tunnel - Remote temp folder: " + remoteTempFolder);

    var remoteScriptPath = String.prototype.concat(remoteTempFolder, '\\HyperVServer.ps1');
    console.log("### SSH Tunnel - Remote script path: " + remoteScriptPath);
    await this.uploadFile(conn, scriptPath, remoteScriptPath);
    
    // we need to upload the logging lib into ps folder because of relative paths which are different in PS-Mode
    var remoteLogScriptPath = String.prototype.concat(remoteTempFolder, '\\Logging.ps1');
    console.log("### SSH Tunnel - Remote script path: " + remoteLogScriptPath);

    // figure out the logging lib path based on the script path
    var path = require('path');
    var scriptFileName = path.basename(scriptPath);
    scriptFileName = scriptFileName.substring(0, scriptFileName.length - 4);
    var logScriptPath = scriptPath.replace(scriptFileName, "Logging");
    await this.uploadFile(conn, logScriptPath, remoteLogScriptPath);
    
    var result = await this.sendCommand(`${this.pwsh} -File ${remoteScriptPath} ${scriptArguments}`, conn);
    result = result.trim();
    //console.log("### SSH Tunnel - Script result: ");
    //console.log(result);
    await this.disconnect(conn);
    console.log("### SSH Tunnel - Script executed");
    return result;
  }

  private async connect(): Promise<Client> {
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
        /*.on('keyboard-interactive', function (this: any, name, descr, lang, prompts, finish) {
        console.log("### SSH Tunnel - Warning: KEYBOARD INTERACTIVE is used. It's not secure.");
        var password = this.config.password;
        return finish([password])
        })*/
        .connect(this.config);
      console.log("### SSH Tunnel - Connected");
    });
  }

  async uploadFile(conn: Client, localPath: string, remotePath: string): Promise<void> {
    await new Promise<void>((resolve, reject) => {
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
    }
    );
  }

  private async sendCommand(command: string, conn: Client): Promise<string> {
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
          .on('close', (code: any, signal: any) => {
            console.log("### SSH Tunnel - Command executed");
            if (code != undefined && Number.parseInt(code) !== 0) {
              console.log("### SSH Tunnel - Error executing command via PowerShell. Exit code: " + code + " Signal: " + signal);
              reject("Error executing command via PowerShell. Exit code:" + code + " Signal:" + signal);
            }
            console.log("### SSH Tunnel - Exit code:" + code + " signal:" + signal);
            resolve(result);
          })
          .on('data', (data: string) => {
            result += data.toString().trim();
            console.log("(SSH-STDIN) " + data.toString().trim());
          })
          .stderr.on('data', (data) => {
            console.log('(SSH-STDERR) ' + data.toString().trim());
            //reject(data.toString().trim());
          });
      });
    });
  }

  private async disconnect(conn: Client): Promise<void> {
    return new Promise((resolve, reject) => {
      console.log("### SSH Tunnel - Disconnecting");
      conn.end();
      console.log("### SSH Tunnel - Disconnected");
    });
  }
}