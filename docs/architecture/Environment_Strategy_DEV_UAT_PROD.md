# Environment Strategy: DEV / UAT / PROD

## Purpose
Define how builds move from development to validated UAT and controlled production deployment.

## Environments

### DEV
- Used for feature development and frequent commits
- Rapid iteration allowed
- Workspace: Insurance-DEV
- Typical branches: main + feature/*

### UAT
- Used for business testing and signoff
- Stable build for validation (no experimental changes)
- Workspace: Insurance-UAT
- Inputs: Release candidate promoted from DEV
- Outputs: UAT signoff + issues log

### PROD
- Used by end users (final consumers)
- Controlled deployments only
- Workspace: Insurance-PROD
- Requires: UAT signoff + release notes + rollback plan

## Promotion Flow
DEV → UAT → PROD

### Rules
- Fixes always go through Pull Requests
- Every UAT issue must be retested after a fix
- PROD deployment happens only after UAT signoff

## Deployment Controls
- Checklist-based deployments
- Rollback plan mandatory
- Post-deployment validation checklist
- Monitoring + refresh schedule documented
