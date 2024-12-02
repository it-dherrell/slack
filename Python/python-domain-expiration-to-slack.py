# This script will scan a .txt file list of domain TLDs then send an alert to a Slack Channel for expiring domains based on the threshold you set.  
# For more information please see the how-to-guide at https://www.daveherrell.com/python-expiring-domain-slack-alerts/

import whois
import requests
from datetime import datetime, timedelta

# Define your input file path containing domain names (one per line)
input_file_path = "/Users/daveherrell/Desktop/domains.txt"

# Define your Slack webhook URL (replace with your actual Slack webhook URL)
slack_webhook_url = "https://hooks.slack.com/services/T0ACBE211/YOURSUPERCOOLWEBHOOK"

# Define the number of days threshold for notification
expiration_threshold = 30

# Initialize a list to collect domains nearing expiration
expiring_domains = []

# Read domains from file and process each
with open(input_file_path, 'r') as file:
    for line in file:
        domain = line.strip()
        
        if domain:
            try:
                # Perform WHOIS lookup
                domain_info = whois.whois(domain)
                
                # Get expiration date and registrar
                expiration_date = domain_info.expiration_date
                registrar = domain_info.registrar

                # Handle cases where expiration_date might be a list
                if isinstance(expiration_date, list):
                    expiration_date = expiration_date[0]

                # Calculate days until expiration
                if expiration_date:
                    days_until_expiration = (expiration_date - datetime.now()).days

                    # Check if the domain is expiring within the threshold
                    if days_until_expiration <= expiration_threshold:
                        expiring_domains.append({
                            "domain": domain,
                            "expiration_date": expiration_date.strftime("%Y-%m-%d"),
                            "days_until_expiration": days_until_expiration,
                            "registrar": registrar
                        })

                    print(f"Processed {domain}: {days_until_expiration} days until expiration")
                else:
                    print(f"No expiration date found for {domain}")
            except Exception as e:
                print(f"Failed to process {domain}: {e}")

# Format and send the message to Slack if there are expiring domains
if expiring_domains:
    slack_message = "Domains Expiring Soon (Within 80 Days):\n"
    for domain_info in expiring_domains:
        slack_message += (
            f"\n*Domain:* {domain_info['domain']}\n"
            f"*Expiration Date:* {domain_info['expiration_date']}\n"
            f"*Days Until Expiration:* {domain_info['days_until_expiration']}\n"
            f"*Registrar:* {domain_info['registrar']}\n"
        )

    # Send the message to Slack
    payload = {"text": slack_message}
    response = requests.post(slack_webhook_url, json=payload)

    if response.status_code == 200:
        print("Message sent to Slack successfully!")
    else:
        print(f"Failed to send message to Slack: {response.text}")
else:
    print("No domains are expiring within the threshold.")
