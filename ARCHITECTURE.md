# Multi-Agent, Multi-Project Workspace — Architecture

How one shared set of Claude Code agents and skills serves many independent projects
(reel-amigos, king-health, virtru-talent-signal, …) on a **single update track**, while each
project keeps its own identity, infrastructure, and knowledge.

---

## The idea in one sentence

> **The agents and skills are generic and shared; everything project-specific is data the
> agents read** — so adding the Nth project is writing one manifest, not copying N agents.

The old way (duplicate a frontend/backend/deploy agent into every repo) means N copies drifting
apart and N places to update. Here, the *logic* lives once in a plugin; the *variation* lives in
each project's `.claude/`.

---

## The pieces

| Piece | What it is | Lives in |
|---|---|---|
| **Marketplace** | A public Claude Code plugin marketplace (`.claude-plugin/marketplace.json`) | `jarededwards/claude-template` (this repo) |
| **`app-platform` plugin** | The shared capability: 3 agents + 3 skills | `plugins/app-platform/` |
| **Project manifest** | `project.yml` — the single source of truth for one project's values | each project's `.claude/` |
| **Project config** | `settings.json` (enables the plugin) + `CLAUDE.md` (prose overview) | each project's `.claude/` |
| **Project knowledge** *(evolving)* | `rules/` (path-scoped) + `knowledge/` (on-demand) — deep, growable per-project context | each project's `.claude/` |

### What the plugin ships
- **Agents** (the workforce): `app-frontend-engineer`, `app-go-backend-engineer`, `app-orchestrator`.
- **Skills** (the procedures): `deploy-app`, `github-issues`, `design-iteration`.

All six are **generic**. None hard-code a project name, registry, namespace, or domain — they
read those from the consuming project's `project.yml`.

---

## How a project is wired (the layers)

```
┌─────────────────────────────────────────────────────────────────┐
│  jarededwards/claude-template  (the marketplace — shared, public) │
│    plugins/app-platform/                                          │
│      agents/   app-frontend · app-go-backend · app-orchestrator   │
│      skills/   deploy-app · github-issues · design-iteration      │
└───────────────▲─────────────────────────────────────────────────┘
                │ enabled via .claude/settings.json (one update track)
   ┌────────────┴───────────┬────────────────────────┬─────────────┐
   │ reel-amigos/.claude    │ king-health/.claude     │ virtru-…/.claude
   │   project.yml  ◄── values (names, repos, deploy targets)       │
   │   settings.json ── enables app-platform@claude-template        │
   │   CLAUDE.md    ◄── prose overview + conventions (auto-loaded)  │
   │   rules/ + knowledge/ ◄── deep per-project context (evolving)  │
   └────────────────────────┴────────────────────────┴─────────────┘
```

When a teammate opens a project in Claude Code and trusts the workspace:
1. `settings.json` registers the marketplace and enables `app-platform` — the agents/skills appear.
2. Those agents **auto-inherit** the project's `CLAUDE.md` (and any path-scoped `rules/`).
3. When an agent acts, its **Step 0** reads `project.yml` for the concrete values.

The result: the *same* `app-go-backend-engineer` behaves correctly in reel-amigos (Civo/Helm,
`gunny-*`) and king-health (GCP/Cloud Run) because it reads each project's manifest.

---

## How the manifest drives behavior

`project.yml` is the contract between the generic logic and the specific project. Example
(abridged):

```yaml
name: reel-amigos
github: { org: reel-amigos, repos: { api: reel-amigos/api, ... } }
services:
  api:       { lang: go, port: 8080, dir: api }
  dashboard: { lang: node, framework: next14, dir: dashboard }
platform:
  provider: civo-helm          # ← the dispatch key
  namespace: gunny
  deploys:
    api: { image: ghcr.io/reel-amigos/api, release: gunny-api, chart: charts/gunny-api }
```

The **`deploy-app` skill** reads `platform.provider` and dispatches to the right recipe — the
*same skill* runs `helm upgrade …` for `civo-helm` and `gcloud run services update …` for
`gcp-cloudrun`. Adding a new platform = one new recipe in the skill, not a new skill per project.

---

## How the agents interact

```
                       ┌──────────────────────┐
   product goal  ───▶  │  app-orchestrator     │  plans, decomposes, maps work → agents
                       │  (does NOT write code) │  (reads the roster + project.yml + CLAUDE.md)
                       └─────────┬────────────┘
            ┌────────────────────┼────────────────────┐
            ▼                    ▼                    ▼
  app-frontend-engineer   app-go-backend-engineer   skills:
  (or a project's          (or a project's          deploy-app · github-issues ·
   specialized agent)       specialized agent)       design-iteration
```

- **Orchestrator-first.** `app-orchestrator` turns a goal into thin vertical slices and maps each
  to an agent — it coordinates, it doesn't implement.
- **Manifest-driven dispatch.** Skills branch on `project.yml` values (e.g. `deploy-app` on
  `platform.provider`, `github-issues` on `github.repos`).
- **Layering / deference.** The common agents are the baseline. A project *may* keep
  **specialized agents** with deep architecture knowledge; the common agents are written to
  **defer** to them. (We're migrating that deep knowledge from specialized *agents* into
  per-project *knowledge* — see below — so the agents stay generic and the depth becomes data.)

---

## How it scales

### Adding a project — write one manifest
1. Copy `project.yml.example` → `<project>/.claude/project.yml`, fill ~40 lines.
2. Add the `settings.json` block that enables `app-platform@claude-template`.
3. Done. The shared agents/skills now work for that project. (See `ONBOARDING.md`.)

### One update track
Improve a skill or agent **once** in this repo → every project pulls it
(`/plugin marketplace update claude-template`). No forks, no re-copying, no drift. The whole point
of the marketplace over per-project copies.

### Per-project knowledge that grows independently *(the evolution)*
Generic agents can't carry every project's deep architecture. Native Claude Code mechanisms give
each project a growable knowledge base the agents load **on demand**:
- **`.claude/rules/*.md`** — path-scoped (`paths:` glob) guidance that auto-loads only when an agent
  touches matching files (e.g. edit `api/internal/fhir/**` → the FHIR rule loads).
- **`.claude/knowledge/*.md` + `INDEX.md`** — deeper, cross-linked docs the agent reads when needed.

So king-health's FHIR/DataService depth becomes king-health's **knowledge** (data the generic
agents read), not duplicated **agents** (code). Each project scales its own knowledge while staying
on the shared agent track. (No native vector RAG — this is curated, indexed markdown read on demand.)

---

## The delivery model (where the agents' work goes)

Each app repo deploys itself; the agents/skills just drive that flow:

```
branch → PR → merge to main → CI (.github/workflows/deploy.yml)
                                   builds linux/amd64 image → ghcr.io/<org>/<repo>:<sha>
                                   kubectl set image deployment/<release> -n <namespace>
```
- `deploy-app` is the manual / reconciling path (Helm), CI is the auto path (on merge).
- Infra (ingress-nginx, cert-manager, external-dns) is declared per project in `charts/cluster/*`.
- Secrets live only in the cluster — never in repos or the manifest.

---

## Decision rights (who owns what)

| Decision | Owner |
|---|---|
| Product vision, priorities, architecture, security boundaries, "Done" sign-off | **Product Owner (human)** |
| Decompose goal → slices, map agents → tasks, sequence, integration | **Orchestrator agent** |
| Routine implementation within guardrails | **Specialist agents** |
| Escalation at risk/security/scope boundaries | **→ Product Owner** |

---

## File map (what lives where)

```
jarededwards/claude-template            ← shared, one update track
├── .claude-plugin/marketplace.json     ← marketplace manifest
├── plugins/app-platform/               ← the plugin (agents + skills)
├── project.yml.example                 ← the manifest schema projects copy
├── README.md · ONBOARDING.md · ARCHITECTURE.md

<each project>/.claude                  ← per-project, scales independently
├── project.yml                         ← values (single source of truth)
├── settings.json                       ← enables the plugin
├── CLAUDE.md                           ← prose overview + conventions
├── rules/ · knowledge/                 ← deep context, on-demand (evolving)
```

---

## TL;DR

- **Agents/skills = shared & generic** (one plugin, one update track).
- **`project.yml` = the contract** that makes generic logic behave per-project.
- **`rules/` + `knowledge/` = per-project depth** the agents read on demand.
- **Adding a project = one manifest.** **Updating a capability = one PR here.**
