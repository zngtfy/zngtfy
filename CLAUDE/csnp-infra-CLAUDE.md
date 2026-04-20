# CSNP Infra — Codebase Guide for Claude

## Project Overview

**`csnp-infra`** is the **Infrastructure-as-Code and runtime configuration repository** for the entire CSNP ecosystem. This repo contains Terraform (VM provisioning), Ansible (configuration management), Nginx edge proxy configs, and Kubernetes setup scripts.

**Scope:** This repo is the **execution layer** — implements the procedures defined in `csnp-docs`. If there is a conflict, `csnp-docs` is authoritative.

**Current environment:** DEV only. UAT/PRO requires architecture review + security approval + state backend hardening before promoting.

**Architecture documentation:** https://github.com/skg-csnp/csnp-docs

---

## Repository Structure

```
csnp-infra/
├── terraform/                   # VM provisioning (Proxmox VE, post-clone only)
│   ├── envs/
│   │   ├── dev/                 # DEV environment — VM definitions per service
│   │   │   ├── backend.tf       # Local state backend
│   │   │   ├── variables.tf     # Proxmox API + SSH key variables
│   │   │   ├── foundation.tf    # Core stateful services (DB, MQ, storage) — currently empty
│   │   │   ├── docker.tf        # docker01-dev (VMID 9161)
│   │   │   ├── harbor.tf        # harbor-backend (VMID 9320)
│   │   │   ├── jenkins.tf       # jenkins-master (VMID 9310) + jenkins-agent-dev (VMID 9311)
│   │   │   ├── k8s.tf           # k8s-master01-dev (9111) + worker01 (9151) + worker02 (9152)
│   │   │   ├── keycloak.tf      # keycloak-backend-dev (VMID 9321)
│   │   │   ├── nginx.tf         # edge-proxy (VMID 9222)
│   │   │   ├── vault.tf         # vault-backend-dev (VMID 9323)
│   │   │   └── outputs.tf       # (empty)
│   │   └── local/               # Local LXC environment (Docker compose for dev services)
│   │       ├── main.tf          # Proxmox LXC container for docker-dev (VMID 111)
│   │       ├── variables.tf     # LXC config: bridge, gateway, IPs, storage
│   │       └── scripts/
│   │           ├── provision-common.sh      # Shared bash functions (log, prepare_system, etc.)
│   │           ├── provision-docker.sh      # Docker CE install script
│   │           └── docker/                  # docker-compose.yml + RabbitMQ/Redis/PostgreSQL configs
│   └── modules/
│       └── vm/                  # Reusable Proxmox VM module (clone from Golden Template)
│           ├── main.tf          # proxmox_vm_qemu resource (q35, OVMF BIOS, cloud-init)
│           ├── variables.tf     # vmid, name, template, bridge, ip, cpu, memory, tags
│           └── outputs.tf
├── ansible/                     # Configuration management
│   ├── ansible.cfg              # Default inventory: dev.ini, roles_path: ../roles, forks=10
│   ├── inventory/
│   │   └── dev.ini              # All DEV hosts grouped by role
│   └── playbooks/
│       ├── site.yml             # All hosts: ssh_hardening; jenkins_masters: jenkins_master
│       ├── install-jenkins-master.yml    # Jenkins LTS + Java 21 installation
│       ├── install-jenkins-agent.yml     # Jenkins agent installation
│       ├── install-nginx.yml             # Nginx installation
│       ├── install-docker.yml            # Docker installation
│       ├── csnp.ssh_hardening.yml        # SSH daemon hardening (disable password + root login)
│       ├── csnp.ssh_keys_create.yml      # Per-host SSH key generation + deployment
│       ├── csnp.ssh_keys_revoke_bootstrap.yml  # Remove bootstrap key (one-way, run after verify)
│       ├── csnp.ssh_keys_revoke_version.yml    # Revoke specific SSH key version
│       └── backup-pfsense.yml            # (empty)
├── roles/                       # Custom Ansible roles
│   ├── csnp.jenkins_master/     # Jenkins LTS + Java 21
│   ├── csnp.jenkins_agent/      # Jenkins agent user + packages + Docker
│   ├── csnp.docker/             # Docker CE + Compose v5.1.1
│   ├── csnp.ssh_hardening/      # SSH daemon hardening
│   ├── csnp.ssh_keys_create/    # Per-host SSH key lifecycle (create/deploy/verify)
│   ├── csnp.ssh_keys_revoke_bootstrap/  # Remove bootstrap key
│   └── csnp.ssh_keys_revoke_version/   # Remove key by version tag
├── edge-proxy/                  # Nginx reverse proxy configs
│   ├── nginx.conf               # Main nginx.conf (base config)
│   └── nginx/
│       ├── envs/
│       │   ├── dev/             # 13 vhost configs (all CSNP DEV services)
│       │   └── uat/             # 5 vhost configs
│       └── snippets/            # Shared include fragments
├── kubernetes/                  # Kubernetes cluster setup
│   ├── kubeadm/                 # Bash scripts: 00-init-all.sh, 01-setup-kube-node.sh, 02-init-master.sh, reset-all.sh
│   ├── argocd/                  # ArgoCD install notes
│   ├── ingress-nginx/           # Ingress NGINX install notes
│   └── operator-tools/          # kubectl aliases
├── ops/
│   ├── dev/infra-dev.sh         # Start/stop all DEV VMs in correct order via Proxmox qm
│   └── uat/infra-uat.sh
├── backups/
│   └── pfsense/                 # pfSense backup storage
└── vpn/                         # VPN configuration notes
```

---

## DEV Environment — VM Inventory

All VMs are provisioned via Terraform from Golden Templates on Proxmox VE. Cloud-init injects hostname, static IP, and SSH key at clone time. Default CI user: `csnp`.

| VMID | Name | Template | Zone | IP | Specs | Tags |
| --- | --- | --- | --- | --- | --- | --- |
| 9222 | `edge-proxy` | rocky-10 | DMZ (`vmbr2`) | `10.10.2.22/24` | 2c / 2GB / 30GB | `tier-edge`, `role-edge-proxy` |
| 9320 | `harbor-backend` | rocky-10 | MGMT (`vmbr3`) | `10.10.3.20/24` | 2c / 4GB / 30GB | `tier-platform`, `role-harbor` |
| 9321 | `keycloak-backend-dev` | rocky-10 | MGMT (`vmbr3`) | `10.10.3.21/24` | 2c / 4GB / 30GB | `tier-platform`, `role-keycloak` |
| 9323 | `vault-backend-dev` | rocky-10 | MGMT (`vmbr3`) | `10.10.3.23/24` | 1c / 2GB / 30GB | `tier-platform`, `role-vault` |
| 9310 | `jenkins-master` | ubuntu-24.04 | MGMT (`vmbr3`) | `10.10.3.10/24` | 2c / 4GB / 30GB | `tier-ci`, `role-jenkins-master`, `privileged-node` |
| 9311 | `jenkins-agent-dev` | ubuntu-24.04 | MGMT (`vmbr3`) | `10.10.3.11/24` | 3c / 6GB / 50GB | `tier-ci`, `role-jenkins-agent` |
| 9111 | `k8s-master01-dev` | ubuntu-24.04 | LAN (`vmbr1`) | `10.10.1.11/24` | 2c / 4GB / 30GB | `tier-k8s`, `role-master`, `privileged-node` |
| 9151 | `k8s-worker01-dev` | ubuntu-24.04 | LAN (`vmbr1`) | `10.10.1.51/24` | 3c / 6GB / 50GB | `tier-k8s`, `role-worker` |
| 9152 | `k8s-worker02-dev` | ubuntu-24.04 | LAN (`vmbr1`) | `10.10.1.52/24` | 2c / 4GB / 50GB | `tier-k8s`, `role-worker` |
| 9161 | `docker01-dev` | ubuntu-24.04 | LAN (`vmbr1`) | `10.10.1.61/24` | 3c / 6GB / 50GB | `tier-docker`, `role-compose` |

**LXC container (local env only):**

| VMID | Name | IP | Specs | Purpose |
| --- | --- | --- | --- | --- |
| 111 | `docker-dev` | `10.10.1.111/24` | 2c / 4GB / 8GB root + 20GB Docker disk | Docker-compose services (Postgres, RabbitMQ, Redis, MinIO) |

**Tag taxonomy:** `env-{dev|uat|pro}` · `tier-{edge|platform|ci|k8s|docker}` · `role-{...}` · `os-{ubuntu|rocky}` · `privileged-node`

---

## Terraform

### VM Module (`terraform/modules/vm/`)

Reusable module wrapping `proxmox_vm_qemu`. Every VM call passes the same interface:

```hcl
module "my-vm" {
  source = "../../modules/vm"

  vmid         = <int>          # Unique Proxmox VMID
  name         = "hostname"
  template     = "ubuntu-24.04-template"   # or "rocky-10-template"
  target_node  = "pve"
  bridge       = "vmbr3"        # Network zone bridge
  ipconfig0    = "ip=10.10.3.X/24,gw=10.10.3.1"
  nameserver   = "10.10.3.1"

  ci_user        = var.default_ci_user   # "csnp"
  ssh_public_key = var.ssh_public_key

  disk_size    = "30G"
  disk_storage = "local-lvm"
  cores        = 2
  memory       = 4096

  tags = ["env-dev", "tier-platform", "role-xyz", "os-ubuntu"]
}
```

**VM spec:** q35 machine, OVMF BIOS, virtio SCSI, cloud-init drive on IDE2. `lifecycle.ignore_changes` on `sshkeys`, `startup_shutdown`, `network` (Proxmox normalizes these internally).

### DEV Environment — Required Variables

Supplied via `terraform.tfvars` or environment variables:

```hcl
proxmox_api_url          = "https://pve.example.com:8006/api2/json"
proxmox_api_token_id     = "terraform@pve!token"
proxmox_api_token_secret = "<secret>"
ssh_public_key           = "ssh-ed25519 AAAA... admin-debian-01-dev|deploy|csnp-infra"
```

State backend: **local** (`terraform.tfstate`) — DEV only. Production requires remote state backend with hardening.

### Common Commands

```bash
cd terraform/envs/dev

terraform init      # Initialize providers + backend
terraform plan      # Review changes before apply
terraform apply     # Clone + provision VMs (DEV only)
terraform destroy   # ⚠️ Permanently destroys all managed DEV VMs
```

**What Terraform manages (post-clone only):** VM clone source, cloud-init drive, static IP, hostname/DNS, SSH key injection, CPU/memory sizing, VM tags.

**What Terraform does NOT manage:** Golden Template lifecycle, OS hardening, application/platform service installation, CI/CD pipelines, secrets.

### Local Environment (`terraform/envs/local/`)

Provisions a **Proxmox LXC container** (`docker-dev`, VMID 111) on the LAN network and uses SSH provisioners to install Docker and spin up `docker-compose`. Used for developer workstation setups.

Services started by `docker-compose.yml`: PostgreSQL, RabbitMQ (with `definitions.json`), Redis (with `users.acl`), MinIO, and optionally MongoDB.

---

## Ansible

### Configuration (`ansible/ansible.cfg`)

- Inventory: `./inventory/dev.ini`
- Roles path: `../roles`
- Remote user: `csnp`, become: `sudo` to root
- SSH args: ControlMaster + ControlPersist 60s + StrictHostKeyChecking no
- Forks: 10, fact caching (jsonfile, 1h TTL at `/tmp/ansible_facts`)
- Logs: `./logs/ansible.log`

### Inventory (`ansible/inventory/dev.ini`)

All DEV hosts — SSH via `csnp-ansible-admin-dev` bootstrap key (switches to per-host keys after `csnp.ssh_keys_create` is verified):

| Group | Hosts | ansible_user | Notes |
| --- | --- | --- | --- |
| `jenkins_masters` | `jenkins-master` | csnp | port 8080 |
| `jenkins_agents` | `jenkins-agent-dev` | csnp | `jenkins_agent_user=jenkins-agent` |
| `nginx_servers` | `edge-proxy` | csnp | DNS: 10.10.2.1, 10.10.3.1, 1.1.1.1 |
| `idp_servers` | `keycloak-backend-dev` | csnp | |
| `vault_servers` | `vault-backend-dev` | csnp | DNS: 10.10.3.1 only |
| `harbor_servers` | `harbor-backend` | csnp | |
| `k8s_masters` | `k8s-master01-dev` | csnp | DNS: 10.10.1.1 |
| `k8s_workers` | `k8s-worker01-dev`, `k8s-worker02-dev` | csnp | DNS: 10.10.1.1 |
| `docker_hosts` | `docker01-dev` | csnp | `docker_compose_version=v5.1.1` |
| `dev` | (all above) | | `env_name=dev`, `domain=csnp.xyz` |

### Playbook Reference

```bash
cd ansible

# SSH hardening (MUST run before key rotation)
ansible-playbook playbooks/csnp.ssh_hardening.yml

# Per-host SSH key lifecycle
ansible-playbook playbooks/csnp.ssh_keys_create.yml -e "ssh_key_version=v1"

# Revoke bootstrap key (ONE-WAY — run ONLY after per-host keys verified)
ansible-playbook playbooks/csnp.ssh_keys_revoke_bootstrap.yml

# Revoke a specific key version
ansible-playbook playbooks/csnp.ssh_keys_revoke_version.yml -e "ssh_key_version=v1"

# Install Jenkins Master
ansible-playbook playbooks/install-jenkins-master.yml

# Install Jenkins Agent
ansible-playbook playbooks/install-jenkins-agent.yml -i inventory/dev.ini

# Apply all (ssh_hardening + jenkins_master on jenkins_masters)
ansible-playbook playbooks/site.yml
```

**Mandatory execution order (SSH lifecycle):**
```
1. Terraform bootstrap (inject temporary SSH key via cloud-init)
2. csnp.ssh_hardening.yml       ← disable password + root login
3. csnp.ssh_keys_create.yml     ← generate + deploy per-host keys (SAFE, idempotent)
4. Verify per-host SSH access manually
5. csnp.ssh_keys_revoke_bootstrap.yml  ← REMOVE bootstrap key (one-way)
```

---

## Ansible Roles

### `csnp.jenkins_master`

Installs Jenkins LTS + OpenJDK 21 on Ubuntu.

**Key defaults:**
- `jenkins_java_version: "21"` → `openjdk-21-jre`
- `jenkins_version: "lts"` from `https://pkg.jenkins.io/debian-stable`
- `jenkins_http_port: 8080`, `jenkins_home: /var/lib/jenkins`
- `jenkins_disable_anonymous_access: true`, `jenkins_disable_user_signup: true`
- `jenkins_authorization_strategy: "role-based"`

**Baseline plugins installed:** `pipeline-model-definition`, `git`, `ssh-slaves`, `ssh-agent`, `pipeline-stage-view`

**Extended plugins:** `credentials-binding`, `docker-workflow`, `configuration-as-code`

**Task flow:** prereq → install_java → install_jenkins → service

### `csnp.jenkins_agent`

**Task flow:** user → packages → docker → yq

- Creates `jenkins-agent` OS user
- Installs: `openjdk-21-jre`, `git`, `ca-certificates`
- Installs Docker (via `csnp.docker` dependency)
- Installs `yq` (YAML processor)

### `csnp.docker`

Installs Docker CE + Compose v5.1.1 on Ubuntu via official APT repo.

**Key defaults:**
- `docker_compose_version: "v5.1.1"`
- `docker_compose_dest: /usr/local/lib/docker/cli-plugins/docker-compose`
- `docker_packages:` `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`
- `docker_users: []` — list of users to add to docker group (inventory: `["csnp"]`)

### `csnp.ssh_hardening`

Applies SSH daemon hardening by modifying `sshd_config`:

```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
```

### `csnp.ssh_keys_create`

Generates and deploys per-host SSH keys. **Safe and idempotent** — no destructive operations.

**Key naming convention:** `csnp-{inventory_hostname}-{ssh_key_version}` (e.g. `csnp-jenkins-master-v1`)

**Key comment format:** `csnp:{env_name}:{inventory_hostname}:ssh-access:{ssh_key_version}`

**Key type:** `ed25519`

**Flow per host:**
1. Generate key pair on Admin Bastion (`delegate_to: localhost`)
2. Deploy public key to target `~csnp/.ssh/authorized_keys`
3. Verify `authorized_keys` contains the key
4. Verify real SSH login using new key

**Required var:** `ssh_key_version` — must be set (e.g. `v1`, `2026Q1`)

### `csnp.ssh_keys_revoke_bootstrap`

Removes the bootstrap key by exact public key match. **One-way operation.** Run ONLY after `csnp.ssh_keys_create` is fully verified.

Bootstrap key pattern: `ssh-ed25519 AAAA... admin-debian-01-dev|deploy|csnp-infra`

### `csnp.ssh_keys_revoke_version`

Removes key by version tag using `lineinfile` with regex matching `ssh-access:{ssh_key_version}$`. Creates backup before removal.

---

## Edge Proxy (Nginx)

Nginx runs on `edge-proxy` (DMZ, `10.10.2.22`). Acts as the **single TLS termination point** — all external HTTPS traffic enters here, forwarded to internal MGMT/LAN services over HTTP.

### TLS Configuration (`snippets/ssl-common.conf`)

```nginx
ssl_certificate     /etc/letsencrypt/live/csnp.xyz/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/csnp.xyz/privkey.pem;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
```

### Available Snippets

| Snippet | Purpose |
| --- | --- |
| `ssl-common.conf` | Let's Encrypt cert + TLS protocols |
| `security-headers.conf` | Security response headers |
| `security-headers-no-frame.conf` | Security headers without X-Frame-Options deny |
| `security-headers-deny-frame.conf` | Security headers with frame deny |
| `proxy-common.conf` | Core proxy_pass headers (Host, X-Real-IP, X-Forwarded-For) |
| `proxy-api.conf` | API-specific proxy settings |
| `proxy-websocket.conf` | `Upgrade` + `Connection: upgrade` headers for WebSocket/SignalR |
| `proxy-large-headers.conf` | Large header buffer for auth-heavy requests |
| `proxy-upload.conf` | Increased body size for file uploads |

All vhosts share the pattern: **HTTP → HTTPS redirect** → HTTPS server with TLS + security headers + proxy_pass.

### DEV Vhost Routing

| Domain | Backend | Notes |
| --- | --- | --- |
| `api-dev.csnp.xyz` | `http://ingress_api_dev` (K8s Ingress) | WebSocket enabled |
| `idp-dev.csnp.xyz` | `http://keycloak-backend-dev.csnp.xyz:8080` | Keycloak |
| `sso-dev.csnp.xyz` | (SSO entry point) | |
| `jenkins.csnp.xyz` | `http://jenkins-master.csnp.xyz:8080` | WebSocket, timeout 3600s |
| `harbor.csnp.xyz` | Harbor backend | Container registry |
| `argocd-dev.csnp.xyz` | ArgoCD backend | GitOps |
| `vault-dev.csnp.xyz` | Vault backend | Secrets |
| `grafana-dev.csnp.xyz` | Grafana backend | Metrics dashboard |
| `prometheus-dev.csnp.xyz` | Prometheus backend | Metrics |
| `minio-dev.csnp.xyz` | MinIO backend | Object storage |
| `backstage-dev.csnp.xyz` | Backstage backend | Developer portal |
| `zor-dev.csnp.xyz` | Blazor WASM portal | Admin UI |
| `admin-dev.csnp.xyz` | Admin API/UI | |
| `dev.csnp.xyz` | (general dev entry) | |

### UAT Vhosts

`api-uat.csnp.xyz`, `sso-uat.csnp.xyz`, `admin-uat.csnp.xyz`, `zor-uat.csnp.xyz`, `uat.csnp.xyz`

---

## Kubernetes

Cluster setup on `k8s-master01-dev` (10.10.1.11) + 2 workers.

**Stack:** kubeadm v1.35, containerd v2.2.1, Calico CNI, Ubuntu 24.04 LTS

**Setup scripts** (run from `k8s-master01-dev` as root):

```bash
sudo ./00-init-all.sh    # Full cluster init (calls 01 + 02 internally)
sudo ./reset-all.sh      # Reset master + all workers (before re-init)
```

| Script | Purpose |
| --- | --- |
| `00-init-all.sh` | Master orchestrator — sets hostnames, runs setup on all nodes, initializes cluster, applies Calico, auto-joins workers |
| `01-setup-kube-node.sh` | Per-node setup — containerd, kubeadm, kubelet, kubectl, swap disabled, sysctl, iptables legacy |
| `02-init-master.sh` | `kubeadm init`, setup `.kube/config`, generate join token, SSH to workers + join |
| `reset-all.sh` | `kubeadm reset` on master + workers via SSH |

**SSH key for master→worker:** `~/.ssh/csnp-deploy-k8s-master-to-worker-dev` (ed25519)

**Post-setup:**
```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -20
```

**Next steps after cluster up:** RBAC + Pod Security → Ingress NGINX (`kubernetes/ingress-nginx/`) → ArgoCD (`kubernetes/argocd/`) → Prometheus + Grafana

---

## Ops Scripts

### `ops/dev/infra-dev.sh` — VM Layer Control

Manages all DEV VMs via Proxmox `qm` CLI. Runs on the **Proxmox host directly**.

```bash
./ops/dev/infra-dev.sh start   # Boot all VMs in correct dependency order
./ops/dev/infra-dev.sh stop    # Graceful shutdown in reverse order (fallback to qm stop)
```

**Start order** (10s wait between layers):
```
1. Platform Services:  vault (9323) → keycloak (9321) → harbor (9320)
2. Kubernetes Cluster: k8s-master (9111) → worker01 (9151) → worker02 (9152)
3. CI Layer:           jenkins-master (9310) → jenkins-agent (9311)
4. Edge:               edge-proxy (9222)
```

**Stop order:** Edge → CI → Kubernetes → Platform (reverse of start)

---

## Security & Key Management

### SSH Key Naming Convention

Per-host keys generated by `csnp.ssh_keys_create`:

```
Filename:  csnp-{inventory_hostname}-{version}
           e.g. csnp-jenkins-master-v1

Key comment: csnp:{env}:{hostname}:ssh-access:{version}
           e.g. csnp:dev:jenkins-master:ssh-access:v1
```

Stored on Admin Bastion at `/home/csnp/.ssh/`.

### Bootstrap Key vs Per-host Keys

| Key Type | Purpose | When to revoke |
| --- | --- | --- |
| Bootstrap key (via Terraform cloud-init) | Initial SSH access for Ansible runs | After `csnp.ssh_keys_create` verified |
| Per-host versioned keys | Ongoing operations | Via `csnp.ssh_keys_revoke_version` |

The `csnp_ssh_revoke_bootstrap.yml` playbook removes the bootstrap key identified by exact match. This is a **one-way operation** — verify per-host keys work before running.

### SSH Hardening Applied (`csnp.ssh_hardening`)

- `PasswordAuthentication no`
- `KbdInteractiveAuthentication no`
- `PermitRootLogin no`
- `MaxAuthTries 3`
- `LoginGraceTime 30`

---

## Environment Configuration

### Network Zones (Proxmox bridges)

| Zone | Bridge | Subnet (DEV) | Gateway | Used by |
| --- | --- | --- | --- | --- |
| LAN | `vmbr1` | `10.10.1.0/24` | `10.10.1.1` | K8s cluster, Docker host |
| DMZ | `vmbr2` | `10.10.2.0/24` | `10.10.2.1` | Edge proxy |
| MGMT | `vmbr3` | `10.10.3.0/24` | `10.10.3.1` | Jenkins, Keycloak, Harbor, Vault |

### Timezone & Locale

All VMs provisioned with `Asia/Ho_Chi_Minh` timezone, `en_US.UTF-8` locale (configured via `provision-common.sh`).

### Docker Compose Services (`terraform/envs/local/scripts/docker/`)

Spun up on `docker01-dev` or the local LXC container:

- **PostgreSQL** — app database
- **RabbitMQ** — with pre-configured `definitions.json` (vhosts, users, queues)
- **Redis** — with `users.acl` (ACL-based access)
- **MinIO** — S3-compatible object storage
- **MongoDB** — provisioned but not currently used by main services

---

## Key Design Principles

- **Golden Templates are immutable** — no identity, SSH keys, or IPs embedded; all injected post-clone via cloud-init
- **Terraform = desired end-state** — no imperative sequencing; Terraform state is source of truth for managed DEV VMs
- **Manual Proxmox changes cause drift** — must be resolved via Terraform, not manual edits
- **Ansible playbooks are idempotent** — safe to re-run; destructive operations (revoke) are separate playbooks
- **SSH key lifecycle is staged** — bootstrap key exists until per-host keys are verified; revocation is explicit and one-way
- **Edge proxy is single TLS entry point** — all services behind Nginx; no service directly exposed on 443
- **DEV mirrors PRO configuration** — vhost comments say "DEV mirrors PROD"; same nginx patterns apply to UAT/PRO
- **Start/stop order matters** — Platform → K8s → CI → Edge (start); reverse for stop

---

## Quick Reference

```bash
# Provision all DEV VMs
cd terraform/envs/dev && terraform apply

# Start all DEV VMs (run from Proxmox host)
./ops/dev/infra-dev.sh start

# Apply SSH hardening to all nodes
cd ansible && ansible-playbook playbooks/csnp.ssh_hardening.yml

# Create per-host SSH keys (version v1)
ansible-playbook playbooks/csnp.ssh_keys_create.yml -e "ssh_key_version=v1"

# After verifying per-host keys — revoke bootstrap
ansible-playbook playbooks/csnp.ssh_keys_revoke_bootstrap.yml

# Install Jenkins Master
ansible-playbook playbooks/install-jenkins-master.yml

# Init Kubernetes cluster (from k8s-master01-dev)
sudo ./kubernetes/kubeadm/00-init-all.sh

# Reset Kubernetes cluster
sudo ./kubernetes/kubeadm/reset-all.sh
```
