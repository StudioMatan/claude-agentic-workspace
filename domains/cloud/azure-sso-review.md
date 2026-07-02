# SSO App Onboarding - Security Review Checklist

Process for onboarding any new application into Entra ID SSO, and for the periodic review of what is already there. Goal: every app authenticates through the identity provider, security approves before go-live, and no app gets broader access than it needs.

## Why SSO-first

If an app is not behind Entra ID, it has its own password, its own MFA story (usually none), and its own offboarding gap - when an employee leaves, that account survives. Routing every app through the IdP means one place to enforce MFA and Conditional Access, one place to cut access on termination, and one sign-in log to hunt in.

## Protocol basics (what you are actually approving)

- **SAML** - XML-based. The app trusts a signed assertion from Entra ID. Legacy but everywhere in enterprise SaaS. Watch: assertion signing certificate expiry, and which attributes/claims are released to the app.
- **OIDC** - OAuth 2.0 plus an identity layer (ID token, JWT). The modern default. Watch: redirect URIs (must be exact, HTTPS), and token lifetimes.
- **OAuth 2.0 consent** - not sign-in, but *permission grants*: an app asking to read mail, files, directory data via Graph. This is where the real risk lives. An app can have harmless SSO and dangerous API permissions.

Rule of thumb: prefer OIDC for new apps, accept SAML when that is all the vendor supports, and scrutinize OAuth permission grants hardest of all.

## Onboarding checklist

Run this for every new enterprise app request:

### 1. Business justification
- [ ] Named business owner for the app
- [ ] Purpose documented - what data does it touch, who uses it
- [ ] Not duplicating an already-approved app (check the existing app inventory first)

### 2. SSO configuration
- [ ] Authentication via Entra ID only - no local vendor accounts for regular users
- [ ] OIDC preferred; SAML acceptable; password-vaulted "SSO" only as a documented exception
- [ ] SAML: signing cert expiry tracked, only required claims released (default is often too much)
- [ ] OIDC: redirect URIs reviewed - exact match, HTTPS, no wildcards

### 3. Permission grants (least privilege)
- [ ] Every requested Graph/API permission justified in writing
- [ ] Delegated permissions preferred over application permissions (delegated acts as the signed-in user; application permissions act tenant-wide with no user context)
- [ ] No admin consent for broad scopes (`Directory.ReadWrite.All`, `Mail.Read` tenant-wide, `Files.ReadWrite.All`) without explicit security sign-off
- [ ] User consent settings verified - users cannot self-consent to risky scopes

### 4. Assignment
- [ ] **Assignment required = Yes.** Never "all users". Assign the specific group that needs the app
- [ ] Access group named for the app and owned by the business owner
- [ ] Guest/external access explicitly decided, default deny

### 5. Naming convention
- [ ] Enterprise app named `<Vendor> - <Product> - <Environment>` (e.g. `Acme - ExpenseTool - Prod`)
- [ ] No test/PoC apps left with default names - they become unidentifiable within a quarter
- [ ] Owner field populated in Entra (both business and technical owner)

### 6. Security sign-off
- [ ] Security review completed and recorded (ticket reference)
- [ ] Conditional Access applies (MFA, compliant device where feasible)
- [ ] Sign-in logs confirmed flowing for the app after go-live

## Periodic review (quarterly)

- Pull all enterprise applications and service principals; flag anything created since last review that skipped the checklist
- Apps with **assignment not required** - fix or justify
- Apps with **zero sign-ins in 90 days** - candidate for removal (each dormant app is standing attack surface)
- OAuth grants review: sort by permission risk, re-justify anything with write or tenant-wide read scopes
- Expiring SAML certificates and client secrets in the next 90 days
- Orphaned apps - owner left the company - reassign or retire
- Cross-check against the software approval list: an app in Entra that was never approved is Shadow IT with a badge

## Red flags that stop onboarding

- Vendor cannot do SSO at all on the purchased tier ("SSO tax") - escalate to procurement, do not accept local passwords silently
- App requests application-level mail/files/directory write on day one
- Multi-tenant app from an unverified publisher requesting admin consent
- "We just need it for a quick pilot with all users assigned"
