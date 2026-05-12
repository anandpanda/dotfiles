---
name: warn-frontend-commit-no-figma
enabled: true
event: bash
conditions:
  - field: command
    operator: regex_match
    pattern: git\s+(commit|push)
  - field: command
    operator: regex_match
    pattern: (application-platform-frontend|apps/application-dashboard)
---

**Frontend commit detected.** Before committing UI changes, verify against the Figma design:

1. **Did you check the Figma design** for the affected component/page?
2. **Layout** — column order, spacing, alignment match?
3. **Typography** — font sizes, weights, colours match the Figma tokens?
4. **Icons** — correct icon set and sizing?
5. **Responsive states** — empty/loading/error states handled?

If the Figma MCP is available, run `get_design_context` on the relevant Figma node before committing. Pattern from this session: Claude committed UI → user spotted mismatch → fix round-trip required (happened 8+ times on `BillingDetailsPage`).
