# n8n

## Overview

n8n is a workflow automation tool with a focus on extensibility and a fair-code distribution model. It provides a node-based approach to automate tasks and integrate disparate systems.

## Deployment Details

- **Chart Version**: 1.0.4
- **Application Version**: 1.81.4
- **Repository**: [8gears/n8n](https://artifacthub.io/packages/helm/open-8gears/n8n)
- **Namespace**: home

## Dependencies

- PostgreSQL database (cloudnative-pg-cluster)
- ExternalSecrets (onepassword)
- Persistent storage (rook-ceph)

## Configuration

- Uses external PostgreSQL database
- Persists data using ceph-block storage
- Configured with Prometheus monitoring
- Accessible via HTTPRoute at n8n.omux.io

## Secrets

Credentials are stored in 1Password and made available via ExternalSecrets:

- Database credentials (username and password)

## Resources

- [Official Documentation](https://docs.n8n.io/)
- [Chart Documentation](https://github.com/8gears/n8n-helm-chart)
- [GitHub Repository](https://github.com/n8n-io/n8n)

## Management

- UI accessible at: [n8n.omux.io](https://n8n.omux.io)
- Authentication configured via environment variables
