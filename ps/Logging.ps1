public void write-LogDebug(string message)
{
    #Used for logging detailed information for debugging purposes. 
    #These messages are only displayed when the workflow is run with the ACTIONS_STEP_DEBUG secret set to true.
    Write-Output "::debug::${message}"
}

public void write-LogNotice(string message,string filename="HyperVServer.ps1")
{
    #Used to provide general information or updates about the workflow. 
    #These messages are displayed in green
    Write-Output "::notice file="$filename":: ${message}"
}

public void write-LogWarning(string message,string filename="HyperVServer.ps1")
{
    #Used to highlight potential issues or warnings in the workflow. 
    #These messages are displayed in yellow.
    Write-Output "::warning file="$filename"::${message}"
}

public void write-LogError(string message,string filename="HyperVServer.ps1")
{
    #Used to indicate errors or failures in the workflow. These messages are displayed in red.
    Write-Output "::error file="$filename"::${message}"
}

public void write-LogInfo(string message)
{
    #Used to provide informational messages about the workflow. 
    #These messages are displayed in white.
    Write-Output "${message}"
}

public void write-LogSectionStart(string sectionName)
{
    Write-Output "::group::${message}"
}

public void write-LogSectionEnd(string sectionName)
{
    # GH doesn't support title for section end
    Write-Output "::endgroup::"
}