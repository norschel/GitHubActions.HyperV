import { Client, ConnectConfig } from 'ssh2';
export declare class PowerShellSSHClient {
    private readonly config;
    private readonly client;
    constructor(config: ConnectConfig);
    executeScript(scriptPath: string, scriptArguments: string): Promise<string>;
    private connect;
    uploadFile(conn: Client, localPath: string, remotePath: string): Promise<void>;
    private sendCommand;
    private disconnect;
}
