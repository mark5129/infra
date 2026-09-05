# infra

Shared infrastructure config for everything on `markusheuer.com`'s server — factored out
of `TravelPlanner` and `SuperMarketReceiptFinder`, which had accumulated near-duplicate
copies of the same CI workflows, Terraform module, and shell scripts.

## What's here

| Path | What | Consumed by each project via |
|---|---|---|
| `terraform/droplet/` | DigitalOcean droplet + DNS + firewall + cloud-init module | Terraform git module source (`git::...//terraform/droplet?ref=vX`) |
| `.github/workflows/issue-dependency-sync.yml` | Reusable `workflow_call` version of the blocked/unblocked label sync | `uses: mark5129/infra/.github/workflows/issue-dependency-sync.yml@main` |
| `.github/actions/*` | Composite actions for the repeated pieces of each project's `deploy.yml` (permission fix, env-file write, smoke test) | `uses: mark5129/infra/.github/actions/<name>@main` |
| `scripts/*.sh` | Docker-compose bind-mounted scripts (nginx dev/prod init, backup, healthcheck) | git submodule at `shared/` in each project (see below) |
| `edge/` | Standalone nginx + certbot stack — the shared reverse proxy / TLS termination for every project on the box | Runs directly from this repo on the server; projects join its networks, they don't embed it |

## Why scripts are a submodule but CI/Terraform aren't

GitHub Actions and Terraform both natively resolve `uses:`/`source:` references straight
from a git repo — no vendoring needed. Docker Compose bind-mounts, on the other hand, need
the file to physically exist in the project's working tree, so those four scripts are
pulled in as a git submodule:

```bash
# one-time, per project repo
git submodule add https://github.com/mark5129/infra.git shared

# after cloning a project repo fresh
git submodule update --init

# bumping the pin once infra changes
git -C shared pull origin main
git add shared && git commit -m "bump shared infra submodule"
```

Each project's compose file then mounts `./shared/scripts/<name>.sh` instead of its own
local copy.

## Why `deploy.yml` itself isn't a single reusable workflow

TravelPlanner's and SMRF's deploy pipelines diverge enough (integration test suite,
extra secrets/env files, differing service lists and smoke-test auth) that forcing them
into one `workflow_call` would need enough conditional inputs to be harder to read than
two short, project-specific files built from the shared composite actions in
`.github/actions/`. Each project keeps its own `deploy.yml` as the readable source of
truth for *which* services start on *which* branch; only the repeated shell blocks inside
it are shared.

## Terraform: migrating a project onto the shared module

See `terraform/droplet/README.md` — moving existing resources into `module "server" {...}`
changes their state address. **Never `terraform apply` that change directly.** Run the
`terraform state mv` commands listed there first, confirm `terraform plan` reports zero
changes, and only then treat the migration as done.

## Edge stack

`edge/` runs independently of any project's compose file, reusing the existing
`travelplanner_web-*` networks and `travelplanner_certbot_*` volumes as `external: true` —
so switching to it needs no cert reissuance and no changes to any project's own
containers. See the cutover sequence in the description of the migration that introduced
this repo (stop TravelPlanner's `nginx`/`certbot` containers, immediately start this stack,
verify, then delete those two service blocks from TravelPlanner's compose file).
