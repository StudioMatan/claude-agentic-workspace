# Office Location -> AD OU Mapping

Used by: `09_Move-OU-TEST.ps1` / `10_Move-OU-FULL.ps1`
Source column: **M (Office Location)** in the ADP report

The key is the exact string value from the ADP report's Office Location column.

## Mapping table

| ADP Office Location | AD OU Distinguished Name |
|---|---|
| Baltimore | `OU=Baltimore,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Bellevue | `OU=Bellevue,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Burlington | `OU=Burlington,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Chicago | `OU=Chicago,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Dallas | `OU=Texas,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Germany | `OU=Germany,OU=Europe,OU=Offices,DC=ad,DC=example,DC=com` |
| Israel | `OU=Tel Aviv,OU=Middle East,OU=Offices,DC=ad,DC=example,DC=com` |
| Japan | `OU=Tokyo,OU=APAC,OU=Offices,DC=ad,DC=example,DC=com` |
| Kitchener | `OU=Waterloo,OU=Canada,OU=Offices,DC=ad,DC=example,DC=com` |
| Los Angeles | `OU=Los Angeles,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Malaysia | `OU=APAC-Remote,OU=Remote Users,DC=ad,DC=example,DC=com` |
| Melbourne - AU | `OU=Melbourne,OU=APAC,OU=Offices,DC=ad,DC=example,DC=com` |
| New York City | `OU=New York,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Philippines | `OU=Philippines,OU=APAC,OU=Offices,DC=ad,DC=example,DC=com` |
| Redwood City | `OU=Redwood City,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| San Diego | `OU=San Diego,OU=USA,OU=Offices,DC=ad,DC=example,DC=com` |
| Singapore | `OU=Singapore,OU=APAC,OU=Offices,DC=ad,DC=example,DC=com` |
| Sydney - AU | `OU=Sydney,OU=APAC,OU=Offices,DC=ad,DC=example,DC=com` |
| Tokyo | `OU=Tokyo,OU=APAC,OU=Offices,DC=ad,DC=example,DC=com` |
| Toronto | `OU=Toronto,OU=Canada,OU=Offices,DC=ad,DC=example,DC=com` |
| United Kingdom | `OU=UK,OU=Europe,OU=Offices,DC=ad,DC=example,DC=com` |
| Remote - Australia | `OU=APAC-Remote,OU=Remote Users,DC=ad,DC=example,DC=com` |
| Remote - <any US state> | `OU=US-Remote,OU=Remote Users,DC=ad,DC=example,DC=com` |

All `Remote - XX` US-state values (AZ, CA, CO, DC, FL, GA, IL, NY, TX, ...) map to the same
`US-Remote` OU - remote workers are grouped by region, not state.

## Notes
- Keys are case-sensitive and must match the ADP column M value exactly.
- If an ADP value has no mapping, the Move-OU script logs `[NO MAPPING]` and skips that user -
  it does not error out.
- When a new office location appears in an ADP report, add it to both this table and the
  `$ouMapping` hashtable in the Move-OU scripts.
- `Japan` maps to the Tokyo OU (same as `Tokyo` - Japan is the ADP label for the Tokyo office).
