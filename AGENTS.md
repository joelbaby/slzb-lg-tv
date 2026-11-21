# LG TV app development

Use GPT-6 Astra or Sol agents. Flash delegation is not authorized for this repository.

## Agent skills

### Issue tracker
Specs and work items live in this repository's GitHub Issues; implementation is reviewed in pull requests. See docs/agents/issue-tracker.md.

### Triage labels
Use the five canonical skill labels. See docs/agents/triage-labels.md.

### Domain docs
Read CONTEXT.md for domain terms and relevant docs/adr/ decisions when present. See docs/agents/domain.md.

## Product contract
The required setup is Pair in the app, then approval on the TV. Do not replace that contract with key import, an external helper, certificate bypass instructions, or an always-on relay without an explicit product decision.

Keep device credentials, user network addresses, captured pairing responses, and local deployment details outside this repository. Publish sanitized evidence only.

Treat the coordinator HTTP client as shared. Establish exclusive use before opening or closing it, bound the operation, and release it on every exit path. Live tests must restore existing automations and preserve their code and startup flags.

Use the documented public app actions and package format as test surfaces. Distinguish command submission from observed TV state. Report only behavior verified on actual supported firmware/models.
