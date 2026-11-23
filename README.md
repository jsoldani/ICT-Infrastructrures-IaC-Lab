# ICT Infrastructures Lab — From Desired State to a Running Service

**Duration:** 2 hours · **Format:** pairs · **Environment:** your laptop, no cloud account

## Scenario

A team needs to deploy a small web service repeatably. Terraform provisions a Docker bridge network. Ansible renders the Compose application definition and applies it. Docker builds and runs two containers: Nginx as a reverse proxy and a small Python API. The page displays a configurable message.

```text
Terraform ── provisions ──> Docker network
Ansible ── renders Compose definition and applies it
Docker Compose ── manages ──> web (Nginx) ──> api (Python)
                                      │             │
                                     :8080          :5000
```

The network has a lifecycle separate from the application. Compose refers to it as an external network, so it must exist before the application starts and must be removed after the application stops. This is a single-host teaching setup, not a highly available production architecture.

## Prerequisites

- Docker Desktop or Docker Engine with Docker Compose v2, running.
- Terraform CLI, Ansible Core, Python 3, and the Docker CLI on the laptop. Docker commands must work from your terminal.
- Internet access for the initial provider and image downloads. The application itself uses no cloud services.
- TCP port `8080` available.

Check the tools before the lab:

```sh
docker version
docker compose version
terraform version
ansible --version
python3 --version
```

On Windows, use WSL2 with Docker Desktop integration and run the lab inside the Linux distribution. No SSH key or Ansible collection is needed: Ansible connects locally.

## Project layout

```text
ict-infrastructures-lab/
├── README.md
├── .gitignore
├── run-lab.sh                 # optional full pipeline
├── terraform/
│   ├── main.tf
│   ├── variables.tf           # TODO: choose the network name
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── ansible/
│   ├── inventory.ini
│   ├── site.yml               # TODO: set app message and matching network name
│   └── templates/compose.yaml.j2
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── nginx.conf
└── teacher/
    └── README.md              # instructor-only answer key
```

This repository contains both the student handout and the instructor guide. Keep the repository private if students should not see the answer key before the lab.

## Two-hour activity

### 0–10 min — Read the starter and complete the initial specification

Before deploying, inspect the files and complete every `TODO` in the Terraform and Ansible starter configuration. These are the initial deployment specifications; do not change the app design yet.

```sh
find . -maxdepth 3 -type f | sort
rg -n 'TODO' terraform ansible
```

Complete these items:

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and replace its TODO with a meaningful Docker network name (for example, `ict-lab-net`). The Terraform variable has no default so the input is explicit.
2. In `ansible/site.yml`, replace both TODOs: set the exact same network name and a short initial app message.
3. Read `ansible/templates/compose.yaml.j2`; confirm the frontend publishes the configured host port, the API is built from `app/`, and both services use the Terraform-managed external network. Check that Nginx forwards to `api:5000` in `app/nginx.conf`.
4. Compare the complete flow to the requirements: one network, two services, API image built locally, Nginx exposed on host port 8080, service-name DNS between containers.

Record which tool owns each resource and the dependency order. Ask the instructor to review the completed initial specifications before the first `apply`.

### 10–25 min — Validate the initial specification

```sh
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Inspect the plan. It should show exactly one network to create and its name should match the value in `ansible/site.yml`. Do not apply if the network names differ. Then return to the project root:

```sh
cd ..
ansible-playbook -i ansible/inventory.ini ansible/site.yml --syntax-check
ansible-playbook -i ansible/inventory.ini ansible/site.yml --check --diff
```

Check-mode output helps review Ansible changes before they are applied. The first run will show the template as changed; the Compose application is intentionally not started during check mode.

### 25–45 min — Provision the network with Terraform

```sh
cd terraform
terraform apply
```

Confirm with `yes`, then inspect the managed state and actual network:

```sh
terraform output
docker network ls
docker network inspect <your-network-name>
cd ..
```

Identify the resource in the plan and compare Terraform's output with Docker's network list. Terraform configuration describes desired state; `terraform.tfstate` records managed resources.

### 45–65 min — Configure and deploy with Ansible

```sh
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

Open <http://localhost:8080> or run:

```sh
curl -i http://localhost:8080
docker compose -f ansible/compose.yaml ps
docker compose -f ansible/compose.yaml logs
```

The first Ansible run renders the Compose file and notifies a handler to apply it. The playbook then checks the HTTP endpoint.

### 65–80 min — Inspect Docker objects and networking

```sh
docker ps
docker image ls
docker network inspect <your-network-name>
docker exec -it ict-lab-api sh
```

Inside the container, run `hostname`, then `exit`. Containers on the user-defined bridge network resolve one another by service/container name. Nginx forwards requests to `api:5000`; only Nginx publishes a port to the laptop.

### 80–100 min — Change the app and observe reconciliation

Now that the initial specification has deployed successfully, change `app_message` in `ansible/site.yml` to a message from your pair. Review then apply:

```sh
ansible-playbook -i ansible/inventory.ini ansible/site.yml --check --diff
ansible-playbook -i ansible/inventory.ini ansible/site.yml
curl http://localhost:8080
```

The template changes and the handler updates the Compose application. Run the playbook once more without edits. The template should report `ok` and the handler should not run.

Cause controlled configuration drift by editing `APP_MESSAGE` directly in the generated `ansible/compose.yaml`. Run Ansible again. The template restores the value declared in `site.yml` and the handler reconciles Compose.

### 100–115 min — Challenge

Choose one:

1. **Parameterize the message:** pass `app_message` with `-e 'app_message=...'`; review with `--check --diff`, apply, and confirm the page changes.
2. **Verify health:** the API already implements `/health`. Add an Ansible URI check for `http://127.0.0.1:8080/health` and confirm it returns `healthy` with HTTP 200.
3. **Discuss ownership:** What happens if someone manually removes the network? Which tool should detect and reconcile it? Why does this starter use Terraform for the network and Compose for the application containers?

### 115–120 min — Share results

Show the page, `terraform output`, Compose service status, and a second Ansible run with no changes. Explain in a few sentences which tool owns the network, application configuration, and running processes.

## Cleanup

Stop the application before removing the network it uses:

```sh
docker compose -f ansible/compose.yaml down
cd terraform
terraform destroy
```

Confirm with `yes`. Terraform removes the managed network; Docker keeps downloaded images. To remove the locally built API image too:

```sh
docker image rm ict-lab-api:1.0
```

Do not run `docker system prune` on a shared machine. Keep the state until you have confirmed the managed network was removed.

## Troubleshooting

| Symptom | Check / fix |
|---|---|
| `Cannot connect to the Docker daemon` | Start Docker Desktop/Engine; check `docker info`; on Linux verify access to the Docker socket. |
| Terraform cannot download the provider | Check Internet/proxy and rerun `terraform init`; keep `.terraform.lock.hcl`. |
| `network ... not found` from Compose | Apply Terraform first; confirm the name in Terraform matches `network_name` in Ansible. |
| Port 8080 already in use | Free it or change `host_port` in `ansible/site.yml`, then rerun Ansible. |
| `curl` returns 502 | Inspect `docker compose ... logs api web`; verify both services use the external network and the API listens on 5000. |
| Old page after changing the message | Check the variable in `site.yml`, template task output, and handler execution. |
| Ansible selects the wrong Python on macOS | The provided inventory selects `ansible_playbook_python`; run Ansible from the intended Python environment. |
| YAML or Compose error | Run Ansible `--syntax-check`; inspect indentation; validate generated config with `docker compose -f ansible/compose.yaml config`. |

## Concepts to take away

- **Dockerfile**: build recipe for the API image. `RUN` is a build step; `CMD` sets the default process at container start.
- **Image**: versioned template (`ict-lab-api:1.0`). **Container**: running instance of an image.
- **Compose**: describes a multi-container application, its ports, build, and network.
- **Terraform**: provisions the local Docker network and records it in state.
- **Ansible**: configures the application deployment through templates and handlers; it uses a local connection.

The Docker provider talks to the Docker Engine API. Compose declares the network external, so it must already exist and its lifecycle remains with Terraform. This lab does not provision a VM or configure a remote host.
