#
# Send message to Slack via PowerShell Script. 
# For more information, check out this link: https://www.daveherrell.com/powershell-basics-send-slack-alert-to-channel/
#
$payload = @{
 "channel" = "#dave-cool-channel"
  "text" = "*Upcoming DNS Outage:*

Scheduled alert: Upcoming DNS outage tomorrow night at 9pm EST. So please add this to your schedule"
  "username"= "Daves Helpdesk Alert"
  "icon_emoji"= ":carebear:"
}

Invoke-WebRequest -UseBasicParsing `
 -Body (ConvertTo-Json -Compress -InputObject $payload) `
 -Method Post `
 -Uri "https://hooks.slack.com/services/T0ACBE211/GETYOUROWNWEBHOOKFORTHIS"
#
# Make sure you update the Slack Webhook with your own!
