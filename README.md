# SYS-350 Module 10: Terraform CI/CD with Dockur VMs

This repository runs my Enterprise Build configuration through a GitHub Actions pipeline. Every push to `cicd-enterprise` is formatted, validated, planned, and policy-checked. After a required approval, the pipeline applies the stack to the lab host and smoke-tests it.

## Stack

All resources carry my `derek-` prefix, and every published port sits in the Student A range (3000-3012) on lab host `192.168.3.224`.

| Resource | Type | Host port(s) |
|---|---|---|
| `derek-gitea` | Docker container (`gitea/gitea`) on `derek-devops-net` | 3000 |
| `derek-apache` | Docker container (`httpd`) on `derek-web-net` | 3001 |
| `derek-win11` | dockur VM container, Windows 11, 4G RAM, 2 vCPU | RDP 3002, viewer 3003 |
| `derek-win2025` | dockur VM container, Windows Server 2025, 4G RAM, 2 vCPU | RDP 3004, viewer 3005 |
| `derek-win11-storage`, `derek-win2025-storage` | Docker volumes mounted at `/storage` | n/a |
| `derek-devops-net`, `derek-internal-net`, `derek-web-net` | Docker bridge networks | n/a |

The Windows containers map `/dev/kvm` and `/dev/net/tun`, add `CAP_NET_ADMIN`, and publish 3389/tcp, 3389/udp, and 8006/tcp. Ports bind to `127.0.0.1` because the host is shared, so I reach RDP through an SSH tunnel:

```bash
ssh -L 3002:localhost:3002 -L 3003:localhost:3003 cncs-sysadmin@192.168.3.224
```

## Repository Layout

| Path | Purpose |
|---|---|
| `main.tf` | Docker provider, variables, networks, service containers, dockur VM containers, outputs |
| `terraform.tfvars` | My lab values (no secrets, so it is committed for this module) |
| `.github/workflows/cicd.yml` | The `check`, `services-test`, and `deploy` jobs |
| `service-images.yaml` | The image manifest that the policy stage enforces |
| `policies/check.sh` | Five bash and jq checks against `plan.json` |
| `tests/smoke.sh` | Stability window, curl probes for services, RDP handshake for Windows |
| `ci/github-services.tfvars` | Services-only variables for the GitHub-hosted lane (`vms = {}`) |

## Pipeline

| Job | Runner | Steps | Runs on |
|---|---|---|---|
| `check` | `ubuntu-latest` | `terraform fmt -check`, `init`, `validate`, `plan`, policy tests | Push and pull request |
| `services-test` | `ubuntu-latest` | Apply gitea and apache as `ci-*`, smoke test, destroy | Push and pull request |
| `deploy` | `[self-hosted, local]` | Approval gate, `plan`, `apply`, full smoke test | Push only |

The `deploy` job uses `needs: [check, services-test]`, so a policy failure never reaches apply. It also uses `if: github.event_name == 'push'`, so a pull request runs the checks and skips deployment. The `environment: enterprise-build` setting pauses the job until a required reviewer approves it. Its checkout step sets `clean: false` so that `terraform.tfstate` survives between runs in the self-hosted runner's workspace.

The self-hosted runner is registered with `--labels local` and installed as a systemd service on the lab host, which provides the `/dev/kvm` device that GitHub-hosted runners lack.

## Repository Visibility

This repository is public because GitHub supports required-reviewer environments on private repositories only for Enterprise plans, and the API returned HTTP 422 on my account. Workflows from outside contributors' pull requests require my approval before they run, and the `deploy` job runs only on pushes to `cicd-enterprise`.

## Changes from the Lesson Files

- **Network dependency:** `docker_container.service` references `docker_network.segment[...].name` instead of rebuilding the name as a string. The container names do not change, but Terraform now knows to create each network before its containers. In the Enterprise Build assignment, I hit the race condition this prevents.
- **Service evidence:** In `services-test`, the evidence steps run before `Cleanup`. In the original order, `terraform destroy` removed the containers before `docker inspect` could read them.
- **Manifest lookup:** `policies/check.sh` matches manifest keys at any indentation, so the YAML can keep standard two-space indentation.
- **RAM rounding:** `RAM_SIZE` uses `floor()` so that a `memory_mb` value that is not a multiple of 1024 still produces a whole number for the policy floor check.

## Sabotage Reflection

For the sabotage lab, I deleted the `capabilities` block that grants `CAP_NET_ADMIN` to the dockur Windows containers in `main.tf`. Before pushing, I predicted that `terraform validate` and `terraform plan` would both pass, because the HCL was still well-formed, and that policy check 1 would fail the run. The prediction was correct: Format, Validate, and Plan were green, and the Policy tests step failed with a VIOLATION line naming `NET_ADMIN` as missing on both `derek-win11` and `derek-win2025`. Without the policy stage, this fault would have passed every syntax check and reached apply.
