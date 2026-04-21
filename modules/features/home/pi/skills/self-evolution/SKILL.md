---
name: self-evolution
description: Detect improvement opportunities and propose system changes through a structured evolution workflow
---

# Self-Evolution Skill

Use this skill when NixPI detects a capability gap or the user requests a system change.

## Choose the Lightest Mechanism

Prefer the lightest viable option: **Skill → Extension → Service**.

| Need | Mechanism | Example |
|---|---|---|
| Pi needs knowledge or a procedure | **Skill** | Operating guide, migration workflow |
| Pi needs tools, hooks, or commands | **Extension** | New tool, prompt injection, guardrails |
| Pi needs an isolated long-running workload | **Service** | LLM server, gateway, daemon |

## Evolution Workflow

1. Detect the gap
2. Search for existing related context in the wiki
3. Create or resolve an evolution page with `wiki_ensure_page`
4. Plan the implementation
5. Implement locally in the repo
6. Validate with tests or checks
7. Prepare the diff for human review
8. Only publish or apply externally with human approval

## Safety Rules

- Prefer local proposals over direct rollout
- Test before suggesting deployment
- Document what changed and why
- Keep rollback paths obvious for NixOS and extension changes
