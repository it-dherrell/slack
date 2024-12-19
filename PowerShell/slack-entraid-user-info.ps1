# This PowerShell script is used along side of Azure Automation, Azure Runbook and a Custom Slack application.  Using a Slack slash command the user is able to retrieve 
# the last login date and password change time.  Easily adjusted for more attribute retrieval.  
# For more information and how-to set this up please see: https://www.daveherrell.com/slack-retrieve-entra-id-ms365-user-information-with-a-slash-command/

param (
    [Parameter(Mandatory=$true)]
    [object] $WebhookData
)

# Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Reports
Import-Module Microsoft.Graph.Users

# Function to format the date in a readable way
function Format-DateTime {
    param (
        [DateTime]$dateTime
    )
    if ($null -eq $dateTime) {
        return "No data available"
    }
    return $dateTime.ToString("MMM dd, yyyy HH:mm:ss tt")
}

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
    $slackBotToken = Get-AutomationVariable -Name "slack-bot-token"
    $botToken = $slackBotToken # Replace with your Slack bot token
    $groupHandle = "@it-team"

    $itTeamMembers = Get-SlackGroupMembers -groupHandle $groupHandle -botToken $botToken
    if (-not ($itTeamMembers -contains $userId)) {
        throw "Unauthorized user. You must be a member of $groupHandle to execute this command."
    }

    if ([string]::IsNullOrEmpty($emailAddress)) {
        throw "Email address not provided in the command"
    }

    Write-Output "Processing request for email: $emailAddress by user: $userId"

    # Connect to Microsoft Graph using managed identity
    Connect-MgGraph -Identity
    
    # Query Microsoft Graph for user
    $filter = "userPrincipalName eq '$emailAddress'"
    $select = "id,userPrincipalName,lastPasswordChangeDateTime,signInActivity"

    try {
        $user = Get-MgUser -Filter $filter -Select $select
        
        if ($null -eq $user) {
            $responseText = "User $emailAddress not found in Azure AD."
        }
        else {
            # Format last password reset
            $formattedPasswordReset = Format-DateTime -dateTime $user.LastPasswordChangeDateTime

            # Extract and format last sign-in activity
            $lastLoginDate = if ($user.SignInActivity.LastSignInDateTime) {
                Format-DateTime -dateTime $user.SignInActivity.LastSignInDateTime
            } else {
                "No login data available"
            }

            $responseText = @"
Here is your info for user: $emailAddress
Last password change was on: $formattedPasswordReset
Last login was on: $lastLoginDate
"@
        }
    }
    catch {
        throw "Error querying user information: $($_.Exception.Message)"
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
