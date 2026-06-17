# Onboarding — get the shared agents & skills on your machine

This repo is a **public Claude Code plugin marketplace**. The `app-platform` plugin
gives you a shared set of agents and skills that work across all the app-platform
projects (reel-amigos, king-health, virtru-talent-signal, …). Nothing project-specific
is baked in — each project carries its own `.claude/project.yml` and the agents/skills
read it.

Takes about 2 minutes. No access tokens, no forks (the repo is public).

---

## Prerequisites
- **Claude Code** installed (`claude` CLI, desktop, or an IDE extension).
- **`gh`** (GitHub CLI) authenticated — the skills use it for issues/PRs/deploys.

---

## Pick one of two setups

### Option A — automatic, per project (recommended for the team)
If you just want to work in an existing project, you don't run any commands. Clone
the project and open it in Claude Code; trusting the workspace auto-registers the
marketplace and enables the plugin (it's committed in the repo's `.claude/settings.json`).

```bash
# example: the Talent Signal workspace
mkdir -p ~/git/github/virtru-talent-signal && cd ~/git/github/virtru-talent-signal
gh repo clone virtru-talent-signal/claude        # contains .claude/ (config) + the dev harness
gh repo clone virtru-talent-signal/api
gh repo clone virtru-talent-signal/dashboard
gh repo clone virtru-talent-signal/charts
ln -sfn claude/.claude .claude                   # workspace .claude → the config (same as other projects)
claude                                            # open Claude Code here, trust the workspace
```
On first launch Claude Code reads `.claude/settings.json`, registers this marketplace,
and enables `app-platform` — the agents and skills are just there.

### Option B — global on your machine (works in any project)
If you want the agents/skills everywhere, install the plugin once from inside Claude Code:

```
/plugin marketplace add jarededwards/claude-template
/plugin install app-platform@claude-template
```

---

## Verify it worked
Inside Claude Code:
```
/plugin list          # app-platform@claude-template should show as enabled
```
You should now have:
- **Agents:** `app-frontend-engineer`, `app-go-backend-engineer`, `app-orchestrator`
- **Skills:** `deploy-app`, `github-issues`, `design-iteration`

Try: ask Claude to "deploy the dashboard" (runs `deploy-app`, which reads `project.yml`),
or "@app-orchestrator plan the next feature."

---

## Starting a brand-new project
The agents/skills are generic; the only thing a new project needs is its manifest.
1. Copy [`project.yml.example`](./project.yml.example) → `<project>/.claude/project.yml` and fill in
   the ~40 lines (identity, github repos, services, `platform.provider`, deploy targets).
2. Add this to `<project>/.claude/settings.json`:
   ```json
   {
     "extraKnownMarketplaces": {
       "claude-template": { "source": { "source": "github", "repo": "jarededwards/claude-template" } }
     },
     "enabledPlugins": { "app-platform@claude-template": true }
   }
   ```
3. Commit both. Anyone who clones the project now gets the full setup via Option A.

---

## Staying up to date
When the agents/skills are improved here, pull the latest:
```
/plugin marketplace update claude-template
```
No re-cloning, no copying files — that's the point of the marketplace over forking.

---

## Troubleshooting
- **Agents/skills don't appear:** confirm `/plugin list` shows `app-platform@claude-template`
  enabled, and that you **trusted** the workspace. Re-open Claude Code in the project dir.
- **A skill says it can't find values:** it reads `.claude/project.yml`. Make sure the project
  has one (Option A repos do; new projects need step 1 above).
- **`gh` errors:** run `gh auth status`; the skills need an authenticated GitHub CLI.
