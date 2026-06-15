---
name: deploy-app
description: >
  Build, push, and deploy a service of this project to its platform.
  Use when the user says "deploy", "ship it", "push the app", "get the new
  image out", "redeploy", or "republish". Platform-agnostic: reads the project
  manifest and dispatches to the correct deploy recipe.
license: MIT
metadata:
  author: jared
  version: "1.0.0"
allowed-tools:
  - Bash(docker build:*)
  - Bash(docker push:*)
  - Bash(helm upgrade:*)
  - Bash(helm status:*)
  - Bash(kubectl rollout status:*)
  - Bash(gcloud run services update:*)
  - Bash(gcloud run services describe:*)
  - Bash(git rev-parse:*)
  - Bash(curl:*)
---

# Deploy App

Generic deploy skill. **Nothing here is hardcoded** — every value comes from
`.claude/project.yml`. The same skill ships unchanged to every project; only the
manifest differs.

## Step 0 — Load the manifest & resolve the target

1. Read `.claude/project.yml`.
2. Determine **which service** to deploy from the user's request (e.g. "deploy
   the dashboard" → `dashboard`). If ambiguous and more than one service has a
   `platform.deploys` entry, ask which one.
3. Pull for that service `<svc>`:
   - `platform.provider` — the dispatch key (which recipe below to run).
   - `platform.deploys.<svc>` — `image`, plus provider-specific fields.
   - `services.<svc>.dir` — Docker build context.
   - `platform.verify_url` — URL to curl after deploy.
4. **Pick an image tag.** Never deploy a mutable `latest` to a cluster. Default
   to the short git SHA of the service's repo:
   ```bash
   git -C <services.<svc>.dir> rev-parse --short HEAD
   ```
   Use a user-supplied tag if they gave one.

Then jump to the recipe matching `platform.provider`.

---

## Recipe: `civo-helm`

Build a `linux/amd64` image, push it to the registry, and roll it out with Helm.

Manifest fields used: `platform.namespace`, `platform.deploys.<svc>.{image,release,chart}`.

### 1. Build (always `--platform linux/amd64`)

```bash
docker build --platform linux/amd64 -t <image>:<tag> <services.<svc>.dir>
```

- macOS builds ARM by default; the cluster runs amd64 — the flag is mandatory.
- Build from the workspace root, not from inside the service dir.

**Success:** `naming to <image>:<tag> done`.

### 2. Push

```bash
docker push <image>:<tag>
```

**Success:** a `digest: sha256:...` line.

### 3. Roll out with Helm

```bash
helm upgrade --install <release> <chart> \
  --namespace <platform.namespace> \
  --set image.repository=<image> \
  --set image.tag=<tag>
```

- Confirm the chart's image value keys first (`image.repository`/`image.tag` is
  the convention; check `<chart>/values.yaml` if unsure).
- Pinned tag, never `latest` — that's why we resolved a SHA in Step 0.

**Success:** `STATUS: deployed`. Then confirm pods rolled:

```bash
kubectl rollout status deployment/<release> -n <platform.namespace>
```

### 4. Verify

```bash
curl -s -o /dev/null -w "%{http_code}" <platform.verify_url>
```

**Success:** `200` (or `307`/`302` redirect to login for an auth-gated app).

---

## Recipe: `gcp-cloudrun`

Build a `linux/amd64` image, push to Artifact Registry, update the Cloud Run service.

Manifest fields used: `platform.deploys.<svc>.{image,service,region,project}`.

### 1. Build

```bash
docker build --platform linux/amd64 -t <image>:<tag> <services.<svc>.dir>
```

- `--platform linux/amd64` mandatory (Cloud Run rejects ARM).
- If `npm ci` fails with missing packages, delete `node_modules` and the lock
  file in the service dir, run `npm install`, then retry.

**Success:** `naming to <image>:<tag> done`.

### 2. Push

```bash
docker push <image>:<tag>
```

**Success:** a `digest: sha256:...` line.

### 3. Deploy to Cloud Run

```bash
gcloud run services update <platform.deploys.<svc>.service> \
  --region=<platform.deploys.<svc>.region> \
  --image=<image>:<tag> \
  --project=<platform.deploys.<svc>.project>
```

**Success:** `Service [...] revision [...] has been deployed and is serving 100 percent of traffic.`

### 4. Verify

```bash
curl -s -o /dev/null -w "%{http_code}" <platform.verify_url>
```

**Success:** `200` (or `307` redirect to login).

---

## Adding a new platform

To support another target (e.g. `fly`, `ecs`, `k8s-kustomize`): add a `provider`
value to a project's manifest and append one `## Recipe: <provider>` section
here. No other file changes — every project that opts in just sets its
`platform.provider`.
