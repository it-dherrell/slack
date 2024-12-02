# Slack PowerShell Scripts

Welcome to my **Slack PowerShell Scripts** section of the repository! This directory contains PowerShell scripts tailored for managing and automating tasks in Slack workspaces. These scripts are designed for administrators looking to leverage PowerShell for efficient Slack management.  For a more indepth step-by-step guide to utilize these scripts please check out: https://www.daveherrell.com/category/slack/

## Features

- **Channel Operations**: Create, archive, or update Slack channels.
- **User Management**: Add, remove, or update user information.
- **Message Automation**: Post messages to channels or users programmatically.
- **Integrations**: Connect Slack to other systems using PowerShell.

## Repository Structure

- **`/PowerShell`**: Contains PowerShell scripts for Slack automation.
- **`README.md`**: Documentation for understanding and using the PowerShell scripts.

## Getting Started

### Prerequisites

1. **Slack API Token**:
   - Obtain a token from the [Slack API](https://api.slack.com/).
2. **PowerShell Environment**:
   - Ensure you have PowerShell 5.1 or higher installed.
   - (Optional) Install the [PSSlack](https://github.com/RamblingCookieMonster/PSSlack) module for additional functionality.

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/it-dherrell/slack.git
   cd slack/PowerShell
   ```

2. Configure your environment:
   - Create a `config.json` file to store your Slack API token and other settings:
     ```json
     {
         "SlackToken": "xoxb-your-slack-token"
     }
     ```

3. Open the scripts in your PowerShell editor to customize them for your workspace.

### Usage

1. Run the desired PowerShell script:
   ```powershell
   .\ScriptName.ps1
   ```

2. Follow any prompts or review the output for results.

## Scripts

- **powershell-alert.ps1**: Basic Slack channel alert using PowerShell.
- **powershell-domain-expiration-to-slack.ps1**: Create a new Slack alert for expiring domains.
- **powershell-ssl-expiration-alerts-to-slack.ps1**: Automate sending SSL expiration alerts to Slack.

## Contributing

Contributions are welcome! If you have additional scripts or improvements, feel free to fork this repository and submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

## Support

If you encounter any issues or have questions, please create an issue in this repository or contact the me direct.

