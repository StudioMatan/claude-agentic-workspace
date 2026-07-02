# Data Sanitization & GitHub Security (always-on)

Applies before ANY git commit or push, in every project.

## Corporate data - NEVER commit

- Company names, internal project names, or brand references
- Employee names, emails, or usernames (except your own author attribution)
- Internal IP addresses (10.x.x.x, 172.16-31.x.x, 192.168.x.x ranges)
- Corporate domain names or AD paths (DC=, OU= with real domains)
- AWS account IDs, ARNs, instance IDs, or role names
- SSH key filenames or paths to credential files
- Internal server hostnames or FQDNs
- Cloud-storage/SharePoint paths containing organization names
- API keys, tokens, or connection strings

## Replacement standards

- Company names: "YourOrg" or "ExampleCorp"
- Emails: user@example.com
- IPs: 10.0.1.x (internal) or 198.51.100.x (RFC 5737 documentation range)
- Domains: example.com, ad.example.com
- AD paths: DC=example,DC=com
- AWS account: 123456789012
- Paths: use `$env:USERPROFILE`, `~/cloud-storage`, or parameters
- Usernames: "AdminUser", "ExampleUser"

## Script best practices

- Always parameterize paths, domains, and OUs (never hardcode)
- Use environment variables for user-specific paths
- Keep author attribution (your name) in script headers - that is fine
- Remove one-time utility scripts before committing

## Before making a repo public

- Rewrite git history (orphan branch) if old commits contain sensitive data
- Scan ALL files with pattern matching for corporate identifiers - a single grep over the tree with the org's names, domains, and IP ranges must return zero hits
- Verify `.gitignore` excludes credential files (`*.pem`, `.env*`, `*.key`)
