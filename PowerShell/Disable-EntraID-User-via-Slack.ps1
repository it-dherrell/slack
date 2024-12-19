# This PowerShell script is used to disable an Entra ID user that's been input and triggered by a Slack slash command.  
# For more information and how to set this up, please see: https://www.daveherrell.com/slack-disable-entra-id-user-using-a-slash-command/

param (
    [Parameter(Mandatory=$false)]
    [object] $WebhookData
)

# Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users

# Function to get Slack group members
function Get-SlackGroupMembers {
    param (
        [string]$groupHandle,
        [string]$botToken
    )
    # Fetch usergroups using Slack API
    $userGroupList = Invoke-RestMethod -Uri "https://slack.com/api/usergroups.list" -Method Get -Headers @{
        "Authorization" = "Bearer $botToken"
    }

    if (-not $userGroupList.ok) {
        Write-Error "Full Slack response: $($userGroupList | ConvertTo-Json -Depth 10)"
        throw "Failed to fetch user groups: $($userGroupList.error)"
    }

    # Find the group ID for the given group handle
    $groupName = $groupHandle.TrimStart('@')
    $group = $userGroupList.usergroups | Where-Object { $_.handle -eq $groupName }
    if (-not $group) {
        throw "Group $groupHandle not found"
    }

    # Fetch members of the group
    $membersResponse = Invoke-RestMethod -Uri "https://slack.com/api/usergroups.users.list?usergroup=$($group.id)" -Method Get -Headers @{
        "Authorization" = "Bearer $botToken"
    }

    if (-not $membersResponse.ok) {
        Write-Error "Full Slack response: $($membersResponse | ConvertTo-Json -Depth 10)"
        throw "Failed to fetch group members: $($membersResponse.error)"
    }

    return $membersResponse.users
}

try {
    # Initialize WebhookData parsing
    $WebhookBody = [System.Web.HttpUtility]::UrlDecode($WebhookData.RequestBody)

    # Convert the body to a hashtable
    $BodyParts = $WebhookBody -split '&'
    $WebhookParams = @{}
    foreach ($Part in $BodyParts) {
        $KeyValue = $Part -split '='
        if ($KeyValue.Count -eq 2) {
            $WebhookParams[$KeyValue[0]] = $KeyValue[1]
        }
    }

    # Extract the email address, response_url, and user_id
    $emailAddress = $WebhookParams['text'].Trim()
    $responseUrl = $WebhookParams['response_url']
    $userId = $WebhookParams['user_id']

    # Validate user is part of @it-team
    $slackBotToken = Get-AutomationVariable -Name "slack-bot-token" # Replace with your Slack bot token variable
    $botToken = $slackBotToken
    $groupHandle = "@it-team"

    $itTeamMembers = Get-SlackGroupMembers -groupHandle $groupHandle -botToken $botToken
    if (-not ($itTeamMembers -contains $userId)) {
        throw "Unauthorized user. You must be a member of $groupHandle to execute this command."
    }

    if ([string]::IsNullOrEmpty($emailAddress)) {
        throw "Email address not provided in the command"
    }

    Write-Output "Processing disable request for email: $emailAddress by user: $userId"

    # List of protected users
    $protectedUsers = @(
        "ceo@daveherrell.com",
        "cfo@daveherrell.com",
        "dave@daveherrell.com"
    )

    # Check if the entered email is in the protected list
    if ($protectedUsers -contains $emailAddress.ToLower()) {
        $responseText = "User $emailAddress cannot be disabled via Slack. Protection enabled."
        Write-Output $responseText
        # Send response back to Slack and exit the script
        $responsePayload = @{
            response_type = "in_channel"
            text = $responseText
        } | ConvertTo-Json -Depth 10 -Compress

        Invoke-RestMethod -Uri $responseUrl -Method Post -ContentType "application/json" -Body $responsePayload
        Write-Output "Response sent to Slack."
        return
    }

    # Connect to Microsoft Graph using managed identity
    Connect-MgGraph -Identity

    # Query and disable Microsoft Graph user
    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$emailAddress'" -Select "id"
        if ($null -eq $user) {
            $responseText = "User $emailAddress not found in Entra ID."
        }
        else {
            # Disable the user by setting accountEnabled to false
            Update-MgUser -UserId $user.Id -BodyParameter @{ "accountEnabled" = $false }
            $responseText = "User $emailAddress has been successfully disabled in Entra ID."
        }
    }
    catch {
        throw "Error disabling user: $($_.Exception.Message)"
    }
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Error "Error occurred: $errorMessage"
    $responseText = "Error: $errorMessage"
}
finally {
    # Disconnect from Microsoft Graph
    Disconnect-MgGraph
}

# Send response back to Slack
try {
    $responsePayload = @{
        response_type = "in_channel"
        text = $responseText
    } | ConvertTo-Json -Depth 10 -Compress

    Invoke-RestMethod -Uri $responseUrl -Method Post -ContentType "application/json" -Body $responsePayload
    Write-Output "Response sent to Slack."
}
catch {
    Write-Error "Failed to send response to Slack: $($_.Exception.Message)"
}
