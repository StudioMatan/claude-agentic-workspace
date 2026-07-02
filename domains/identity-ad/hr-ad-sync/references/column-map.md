# ADP Report Column Map

Source file: `./data/ADP Report/ADP Feed Report_ IT (<Month><YY>).xlsx`

- Row 1: blank (skip)
- Row 2: headers
- Row 3+: data

| Column | Header | Used for |
|--------|--------|----------|
| A | Payroll Name | ignored |
| B | Preferred or Chosen Name | ignored |
| C | Preferred or Chosen First Name | ignored |
| D | Preferred or Chosen Last Name | ignored |
| E | Legal First Name | ignored |
| F | Legal Last Name | ignored |
| G | Hire Date | ignored |
| **H** | **Work Contact: Work Email** | **SamAccountName** (strip `@example.com`) |
| **I** | **Job Title Description** | **-> AD Title + AD Description** |
| J | Home Department Description | ignored (Department pushed separately if needed) |
| **K** | **Reports to Email** | **-> AD Manager** (full email for Mail lookup) |
| L | A2 - Manager | Manager display name - used for name-based comparison only |
| **M** | **Office Location** | **-> OU placement** (see ou-mapping.md) |
| N | GEO | ignored |

## Key rules
- Column H email -> SamAccountName: strip everything from `@` onward
  - `jsmith@example.com` -> `jsmith`
- Column K and H stay as full emails in Manager_*.csv (AD lookup via `Mail` attribute)
- Column M value is used verbatim as the key into the OU mapping table
- Always validate these headers on a new report before running scripts
