# claude-template

A Claude Code **plugin marketplace** of generic, manifest-driven agents and skills
shared across app-platform projects (reel-amigos, king-health, virtru-talent-signal, …).

The core idea: **the plugin logic is identical everywhere; everything
project-specific lives in each repo's `.claude/project.yml`.** Onboarding a new
project is writing one ~40-line manifest — not copying and editing N agent files.

## What's in the box

The `app-platform` plugin provides:

**Common agents** (baseline; defer to a project's specialized agents when present):
- `app-frontend-engineer` — Next.js / React / Tailwind
- `app-go-backend-engineer` — Go + Gin/HTTP services
- `app-orchestrator` — Team Lead Orchestrator (planning/decomposition, no code)

**Skills** (all read `.claude/project.yml`):
- `deploy-app` — build → push → deploy. Dispatches on `platform.provider`
  (`civo-helm` → Helm, `gcp-cloudrun` → Cloud Run). Add a provider = add one recipe.
- `github-issues` — create/manage issues against the repos in `github.repos`.
- `design-iteration` — track design handoff zips as diffable PRs in the project's
  design-archive (path from `design.archive_dir`).

## The layering model (no regression)

Common agents are the **baseline**. A project may keep **specialized agents** in its
own `.claude/agents/` that encode deep architecture (e.g. king-health's FHIR-proxy
and data-layer agents). Specialized agents are kept verbatim and **always take
precedence** — the common agents explicitly defer to them. Greenfield projects use
the common agents until/unless they grow specialists.

```
specialized project agent  (deep architecture)   ← preferred when it exists
        └── falls back to ──┐
common app-platform agent   (portable conventions + reads project.yml + CLAUDE.md)
```

## Use it in a project

1. Copy [`project.yml.example`](./project.yml.example) to `<project>/.claude/project.yml`
   and fill in the values.
2. Register the marketplace and enable the plugin in `<project>/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-template": {
      "source": { "source": "github", "repo": "jarededwards/claude-template" }
    }
  },
  "enabledPlugins": {
    "app-platform@claude-template": true
  }
}
```

Teammates who clone the repo get the agents/skills automatically once they trust the
workspace — no `/plugin install` step, no access tokens, no forks.

## Repo layout

```
claude-template/
├── .claude-plugin/marketplace.json     # marketplace manifest
├── plugins/app-platform/
│   ├── .claude-plugin/plugin.json
│   ├── agents/                         # app-frontend / app-go-backend / app-orchestrator
│   └── skills/                         # deploy-app / github-issues / design-iteration
├── project.yml.example                 # the manifest schema projects copy
└── README.md
```
