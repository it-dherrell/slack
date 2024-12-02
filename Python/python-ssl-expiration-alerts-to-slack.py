# This script will read from a txt file of URLs, scan and validate the urls SSL Certificate.  Then send alerts to a designated Slack channel if any SSL certs are set to expire within the amount of days you set.
# For more information please check out: https://www.daveherrell.com/python-send-ssl-cert-expirations-to-slack/

import socket
import ssl
import datetime
import requests

# Make sure you define the path to the URL file
urls_file = "/Users/daveherrell/Desktop/urls.txt"

# Go grab your Slack Webhook URL and place it below
slack_webhook_url = "https://hooks.slack.com/YOURWEHOOKURLHERE"

# Set the number of days to check for certificate expiration.  Keep in mind that most SSL providers only allow you to renew certs within 30 days of expiration.
warning_days = 90

# Function to fetch SSL certificate information
def get_ssl_certificate_info(url):
    try:
        hostname = url.replace("https://", "").replace("http://", "").split("/")[0]
        context = ssl.create_default_context()
        
        with socket.create_connection((hostname, 443)) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()
        
        not_after = datetime.datetime.strptime(cert['notAfter'], "%b %d %H:%M:%S %Y %Z")
        issuer = dict(x[0] for x in cert['issuer'])['organizationName']
        registrar = cert.get('subjectAltName', [(None, hostname)])[0][1]
        
        return {
            "url": url,
            "issuer": issuer,
            "not_after": not_after,
            "registrar": registrar,
            "is_valid": True
        }
    except Exception as e:
        print(f"Failed to fetch certificate for {url}: {e}")
        return None

# Function to send Slack notification
def send_slack_notification(message):
    payload = {
        "text": message
    }
    response = requests.post(slack_webhook_url, json=payload)
    if response.status_code != 200:
        print(f"Failed to send Slack message: {response.status_code}, {response.text}")

# Read URLs from file and process each
try:
    with open(urls_file, "r") as f:
        urls = [line.strip() for line in f if line.strip()]

    for url in urls:
        cert_info = get_ssl_certificate_info(url)
        if cert_info and cert_info["is_valid"]:
            days_to_expire = (cert_info["not_after"] - datetime.datetime.utcnow()).days
            if days_to_expire <= warning_days:
                message = (
                    f"SSL Certificate for {cert_info['url']} issued by {cert_info['issuer']} "
                    f"(Registrar: {cert_info['registrar']}) will expire in {days_to_expire} days "
                    f"on {cert_info['not_after'].strftime('%Y-%m-%d')}."
                )
                send_slack_notification(message)
                print(message)
        else:
            print(f"Invalid certificate for {url} or unable to retrieve certificate.")
except FileNotFoundError:
    print(f"URLs file not found at {urls_file}")
