# This script scans a TXT file of URLs for their installed SSL certifcates.  Checks their validation and expiration date.  Sends alerts to a Slack channel if expiration in your set amount of days.
# For more information on this script please check out https://www.daveherrell.com/powershell-basics-send-ssl-cert-expirations-to-slack/

# Mak sure you define your path to the URL file
$urlsFile = "/Users/daveherrell/Desktop/urls.txt"

# Define your Slack Webhook URL
$slackWebhookUrl = "https://hooks.slack.com/services/YOURAWESOMEWEBHOOKURLHERE"

# Set the number of days to check for certificate expiration
$warningDays = 90

# Function to fetch SSL certificate information
function Get-SSLCertificateInfo {
    param (
        [string]$url
    )

    try {
        $uri = New-Object System.Uri($url)
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($uri.Host, 443)
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, ({ $true }))
        $sslStream.AuthenticateAsClient($uri.Host)
        
        $cert = $sslStream.RemoteCertificate
        $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $cert
        $tcpClient.Close()

        return @{
            Url = $url
            Issuer = $cert2.Issuer
            NotAfter = $cert2.NotAfter
            Registrar = $cert2.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::DnsName, $false)
            IsValid = $cert2.Verify()
        }
    } catch {
        Write-Output "Failed to fetch certificate for $url"
        return $null
    }
}

# Function to send Slack notification
function Send-SlackNotification {
    param (
        [string]$message
    )

    $payload = @{
        text = $message
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -ContentType 'application/json' -Body $payload
}

# Read URLs from file
if (Test-Path $urlsFile) {
    $urls = Get-Content -Path $urlsFile
    foreach ($url in $urls) {
        $certInfo = Get-SSLCertificateInfo -url $url
        if ($certInfo -ne $null -and $certInfo.IsValid) {
            $daysToExpire = ($certInfo.NotAfter - (Get-Date)).Days
            if ($daysToExpire -le $warningDays) {
                $message = "SSL Certificate for $($certInfo.Url) issued by $($certInfo.Issuer) (Registrar: $($certInfo.Registrar)) will expire in $daysToExpire days on $($certInfo.NotAfter)."
                Send-SlackNotification -message $message
                Write-Output $message
            }
        } else {
            Write-Output "Invalid certificate for $url or unable to retrieve certificate."
        }
    }
} else {
    Write-Output "URLs file not found at $urlsFile"
}
