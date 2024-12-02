# This script will scan a .txt file list of domain TLDs then send an alert to a Slack Channel for expiring domains based on the threshold you set.  
# For more information please see the how-to-guide at https://www.daveherrell.com/powershell-basics-expiring-domain-slack-alerts/

# Define the path to your input file containing domain names (one per line)
$inputFilePath = "/Users/daveherrell/Desktop/domains.txt"

# Define your Slack webhook URL (replace with your actual Slack webhook URL)
$slackWebhookUrl = "https://hooks.slack.com/services/LOTSOFNUMERSANDLETTERS"

# Define the number of days threshold for notification
$expirationThreshold = 30

# Check if the input file exists
if (-not (Test-Path $inputFilePath)) {
    Write-Output "Input file not found at $inputFilePath"
    exit
}

# Initialize an array to collect the domains nearing expiration
$expiringDomains = @()

# Loop through each domain in the input file
Get-Content $inputFilePath | ForEach-Object {
    $domain = $_.Trim()
    
    if ($domain) {
        try {
            # Perform WHOIS lookup using the `whois` command
            $whoisInfo = whois $domain

            # Determine the TLD of the domain (e.g., .com, .org, etc.)
            $tld = ($domain -split "\.")[-1]

            # Parse expiration date and registrar based on TLD
            if ($tld -eq "org") {
                # Parsing for .org domains
                $expirationDateString = ($whoisInfo | Select-String -Pattern "Registry Expiry Date:\s*(.*)").Matches[0].Groups[1].Value.Trim()
                $registrar = ($whoisInfo | Select-String -Pattern "Registrar:\s*(.*)").Matches[0].Groups[1].Value.Trim()
            } else {
                # Default parsing for other domains (like .com)
                $expirationDateString = ($whoisInfo | Select-String -Pattern "Expiration Date:\s*(.*)").Matches[0].Groups[1].Value.Trim()
                $registrar = ($whoisInfo | Select-String -Pattern "Registrar:\s*(.*)").Matches[0].Groups[1].Value.Trim()
            }

            # Parse the expiration date
            $expirationDate = [datetime]::Parse($expirationDateString)

            # Calculate days until expiration
            $daysUntilExpiration = ($expirationDate - (Get-Date)).Days

            # Check if the domain is expiring within the threshold
            if ($daysUntilExpiration -le $expirationThreshold) {
                # Add the expiring domain information to the array
                $expiringDomains += [PSCustomObject]@{
                    Domain = $domain
                    ExpirationDate = $expirationDate
                    DaysUntilExpiration = $daysUntilExpiration
                    Registrar = $registrar
                }
            }

            Write-Output "Processed $domain"
        } catch {
            Write-Output "Failed to process {$domain}: $_"
        }
    }
}

# Format the message to send to Slack if there are expiring domains
if ($expiringDomains.Count -gt 0) {
    $slackMessage = "Domains Expiring Soon (Within $expirationThreshold Days):`n"
    foreach ($domainInfo in $expiringDomains) {
        $slackMessage += "`n*Domain:* $($domainInfo.Domain)`n*Expiration Date:* $($domainInfo.ExpirationDate.ToString("yyyy-MM-dd"))`n*Days Until Expiration:* $($domainInfo.DaysUntilExpiration)`n*Registrar:* $($domainInfo.Registrar)`n"
    }

    # Send the message to Slack
    try {
        $payload = @{
            text = $slackMessage
        }
        $payloadJson = $payload | ConvertTo-Json -Compress

        Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -ContentType "application/json" -Body $payloadJson

        Write-Output "Message sent to Slack successfully!"
    } catch {
        Write-Output "Failed to send message to Slack: $_"
    }
} else {
    Write-Output "No domains are expiring within $expirationThreshold days."
}

Write-Output "Done!"
