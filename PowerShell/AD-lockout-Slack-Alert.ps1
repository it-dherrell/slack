# This script will scan Active Directory for any locked out accounts, then send an alert to your desired Slack channel alerting about it. 
# Recommended you set this up via a Scheduled Task on your Windows Server. 
# More info can be found here: https://www.daveherrell.com/powershell-basics-send-slack-alert-for-locked-out-users

# Webhooks Channel
$SlackChannelUri = "https://hooks.slack.com/services/GETYOUROWNWEBHOOK"
$ChannelName = "#dave-test"
 
$BodyTemplate = @"
    {
        "channel": "CHANNELNAME",
        "username": "AD Users Locked Out",
        "text": "*DOMAIN_USERNAME* account is currently locked out. \nTime: DATETIME.",
        "icon_emoji":":closed_lock_with_key:"
    }
"@
 
 
if (Search-ADAccount -LockedOut){
    foreach ($user in (Search-ADAccount -LockedOut)){
        $body = $BodyTemplate.Replace("DOMAIN_USERNAME","$user").Replace("DATETIME",$(Get-Date)).Replace("CHANNELNAME","$ChannelName")
        Invoke-RestMethod -uri $SlackChannelUri -Method Post -body $body -ContentType 'application/json'
    }
}
