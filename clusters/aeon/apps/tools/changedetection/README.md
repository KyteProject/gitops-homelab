# changedetection.io

## Overview

changedetection.io is a self-hosted tool for monitoring website changes with email and webhook notifications. It allows you to track changes on webpages and receive alerts when content is updated.

## Deployment Details

- **Application Version**: 0.49.4
- **Chart**: app-template (from bjw-s)
- **Namespace**: tools

## Dependencies

- Persistent storage via VolSync (backed by rook-ceph)
- ExternalSecrets (onepassword)
- Browserless Chrome for headless browser capabilities

## Configuration

- Uses VolSync for data persistence with automatic backups
- Integrated with Prometheus monitoring
- Configured with headless browser support for JavaScript rendering
- Accessible via HTTPRoute at changedetection.omux.io
- Container health probes for improved reliability

## Features

- Monitor any website for visual, text or HTML changes
- Support for monitoring websites requiring JavaScript
- Notifications via various services (email, Discord, Slack, etc.)
- Visual comparison of changes
- Regular expression filtering
- Scheduled monitoring during specific times
- CSS/JSON/Xpath selectors for specific content monitoring

## Secrets

Credentials are stored in 1Password and made available via ExternalSecrets:

- WebDriver API key (if needed)

## Resources

- [Official Documentation](https://github.com/dgtlmoon/changedetection.io/wiki)
- [GitHub Repository](https://github.com/dgtlmoon/changedetection.io)

## Management

- UI accessible at: [changedetection.omux.io](https://changedetection.omux.io)
- Authentication configured via environment variables
- Data automatically backed up via VolSync
