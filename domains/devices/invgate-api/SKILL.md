---
name: invgate-api
description: Query the InvGate Insight API live - look up assets by serial, find device owners, check if a user/device is still in the organization, detect offboarded users and returned laptops. Use when the analyst says "check InvGate", "look up this serial", "is this device still assigned", "does this user still have a device", or any device/user lookup that static exports can't answer live.
---

# InvGate Insight API (live, read-only)

## Access
- Base: `https://yourorg.cloud.invgate.net`
- Auth: OAuth2 client_credentials at `POST /oauth2/token/` -> short-lived bearer
- Credentials: password-manager item referenced from `.env.op`
  (`op://Vault/invgate-api-readonly/...`), injected via `op run --env-file .env.op`.
  The script reads `os.environ` only - zero credential logic in code.
- The read-only key has people (directory) access as well as assets - full
  serial -> asset -> owner -> person resolution in one pass

## Critical gotchas
1. **API lives at `/public-api/`, NOT `/api/v1/`** (old paths return the SPA's HTML 404)
2. **Must send `Accept: application/vnd.api+json`** - plain `application/json` returns 406
3. **Query/filter params are silently ignored** (`?q=`, `?search=`, `filter[serial]=` all
   return the full unfiltered set) - paginate everything and filter client-side
4. **One `op run` per task** - batch ALL calls into a single script invocation; repeated
   `op run` calls re-prompt the analyst for password-manager auth

## Endpoints
| Endpoint | Returns |
|---|---|
| `GET /public-api/people/` | ~1,400 people: name, email, position, department, person_type, is_deleted |
| `GET /public-api/people/{id}/` | single person |
| `GET /public-api/assets-lite/` | ~2,000 assets: name, serial, inventory_id, reported_at, asset_type, default_ip + relationships (owner, status, location, device_model) |
| `GET /public-api/assets-lite/{id}/?include=owner,status,location,device_model` | single asset with related records resolved in `included` |
| `GET /public-api/locations/` / `{id}/` | location tree (full_path like "United Kingdom > London Office") |

Pagination: JSON-API style - `?page=N&page_size=100`, follow `links.next` until null.
Response shape: `{"links": {...}, "data": [{"type","id","attributes","relationships"}], "included": [...]}`.

## Canonical script
`scripts/invgate_lookup.py` - run:
```bash
op run --env-file .env.op -- python3 invgate_lookup.py <SERIAL or username>
```

## Interpreting results (org conventions - adapt to yours)
- Person name prefixed **"X - "** = offboarded/leaver (record kept, `is_deleted` stays false)
- Asset owner reassigned to **it@example.com** (the IT shared identity) + status
  **"In Stock"** = laptop returned to IT
- `reported_at` = last agent check-in; an In Stock device still reporting means it's
  powered on (office/re-prep), not necessarily assigned
- To check "does user X have a new device": scan all assets for owner = person id OR
  name containing username - one pass answers both old and new device questions
- Asset naming convention: `<username>-<SERIAL>`

## Rules
Read-only GETs only. Never persist the token - mint per run, let it expire.
Follows the credential pattern in `../../../rules/secret-handling.md`.
