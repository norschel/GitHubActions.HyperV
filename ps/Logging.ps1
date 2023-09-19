function write-LogDebug($message)
{
    #Used for logging detailed information for debugging purposes.
    #These messages are only displayed when the workflow is run with the ACTIONS_STEP_DEBUG secret set to true.
    #Write-Output "::debug::${message}"
}

function write-LogNotice($message,$filename="HyperVServer.ps1")
{
    #Used to provide general information or updates about the workflow.
    #These messages are displayed in green
    Write-Output "::notice file=""$filename""::${message}"
}

function write-LogWarning($message,$filename="HyperVServer.ps1")
{
    #Used to highlight potential issues or warnings in the workflow.
    #These messages are displayed in yellow.
    Write-Output "::warning file=""$filename""::${message}"
}

function write-LogError($errorMessage,$filename="HyperVServer.ps1")
{
    #Used to indicate errors or failures in the workflow.
    #These messages are displayed in red.
    Write-Output "::error file=""$filename""::${errorMessage}"
}

function write-LogInfo($message)
{
    #Used to provide informational messages about the workflow. 
    #These messages are displayed in white.
    Write-Output "${message}"
}

function write-LogSectionStart($sectionName)
{
    Write-Output "::group::${sectionName}"
}

function write-LogSectionEnd($sectionName)
{
    # GH doesn't support title for section end
    Write-Output "::endgroup::"
}
write-output "Imported PowerShell logging functions for GitHub Actions"
