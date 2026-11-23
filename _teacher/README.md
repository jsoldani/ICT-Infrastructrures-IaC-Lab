# Instructor Guide — Reference Answers and Teaching Notes

## Teaching goals

Students distinguish infrastructure provisioning from service configuration, follow an application from Dockerfile to image to running containers, read a Terraform plan and state, interpret Ansible `ok`/`changed`, use service-name DNS on a user-defined bridge, and explain lifecycle ordering, idempotence, and drift.

## Suggested 120-minute schedule

| Time | Activity | Expected outcome |
|---:|---|---|
| 0–10 | Scenario, tool roles, prereq check | Docker and CLIs available |
| 10–25 | Complete the starter's initial specification | TODOs replaced; Terraform and Ansible network names match |
| 25–35 | Validate and review Terraform/Ansible | One network in plan; playbook syntax valid |
| 35–50 | Terraform apply and inspect | `ict-lab-net` exists and is recorded in state |
| 50–70 | Ansible render/deploy/HTTP check | Both services respond at localhost:8080 |
| 70–85 | Inspect Docker images, containers, network, logs | Understand port mapping and internal DNS |
| 85–100 | Change message, repeat, induce drift | Handler runs only after relevant change |
| 100–115 | Challenge | Variable or health check completed |
| 115–120 | Share results and cleanup reminder | Ownership and lifecycle are clear |

Build/download time may vary by laptop and network. For a shorter session, pre-pull `nginx:1.27-alpine` and `python:3.13-alpine` and cache the provider.

## Reference completion for the initial specification

Students should copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`, replace the placeholder, and set the identical network name in `ansible/site.yml`. A valid completion is:

`terraform/terraform.tfvars`

```hcl
network_name = "ict-lab-net"
```

Relevant `ansible/site.yml` values:

```yaml
    network_name: ict-lab-net
    app_message: ICT Infrastructures lab
    app_image: ict-lab-api:1.0
    host_port: 8080
```

The network must match across both tools because Terraform creates it while Compose references it with `external: true`. The remaining Compose requirements are represented in the starter template: API builds from the local Dockerfile, Nginx publishes port 8080, and both services attach to the external network.

### Expected command sequence

```sh
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform.tfvars and ansible/site.yml to remove TODO values
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan
ansible-playbook -i ansible/inventory.ini ansible/site.yml --syntax-check
ansible-playbook -i ansible/inventory.ini ansible/site.yml --check --diff
terraform -chdir=terraform apply
ansible-playbook -i ansible/inventory.ini ansible/site.yml
curl -i http://localhost:8080
```

Plan should show exactly one `docker_network` resource. Ansible check mode should report a changed template on the initial run but not start Compose. Terraform must be applied before the Ansible deploy.

## Reference architecture and code ownership

1. `terraform/main.tf` declares the Docker provider and one `docker_network.lab` resource. Terraform state records the network ID.
2. `ansible/site.yml` targets localhost using the local connection. The template module writes `ansible/compose.yaml`; a handler applies Compose when that file changes.
3. Compose describes API and Nginx. The API image builds locally; Nginx publishes `8080:80` and sends requests to `api:5000` using Docker DNS.
4. The network is external to Compose, so Compose does not create or delete it. `ansible.builtin.uri` checks the completed HTTP service.
5. Cleanup order is `docker compose ... down`, then `terraform destroy`. The images remain cached locally.

## Challenge answers

### Pass a message as a variable

```sh
ansible-playbook -i ansible/inventory.ini ansible/site.yml -e 'app_message=Group demo message'
```

Because the value is used by the Compose template, Ansible reports a change and runs the handler. Compose recreates the API container with the new environment variable.

### Check the health endpoint

`app/app.py` already serves `/health` with HTTP 200 and body `healthy`. Add a task such as:

```yaml
    - name: Check API health endpoint
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ host_port }}/health"
        return_content: true
        status_code: 200
      register: health_check
      until: health_check.status == 200
      retries: 8
      delay: 2
      when: not ansible_check_mode
```

Verify from the host with `curl http://localhost:8080/health`.

## Discussion prompts and expected answers

- **Why does Terraform create the network while Compose does not?** It makes infrastructure and application lifecycle boundaries explicit. Compose depends on the network but does not own it.
- **Why does Ansible connect to localhost rather than SSH?** The Docker Engine is local. This demonstrates inventory, plays, modules, templates, handlers, and idempotence without provisioning a VM or distributing credentials.
- **Where is the published port?** Only Nginx exposes a host port. The API is reachable to peer containers on port 5000 through the service name.
- **What if Terraform destroy fails?** A container may still be attached. Stop/remove the Compose application first, then retry destroy.
- **Is the playbook idempotent?** The template is idempotent; its handler runs only when rendered content changes. The URI task checks service state. On an unchanged second run, the template reports `ok`, so the handler is skipped.
- **Why not have Terraform own the app containers too?** That would create overlapping lifecycle ownership with Compose. The lab separates Terraform-managed infrastructure from Compose-managed services, with Ansible configuring and applying the application definition.

## Optional full pipeline

`./run-lab.sh` runs Terraform init, validate, plan, apply, then Ansible. In class, start with separate commands so students can inspect the plan and see each tool's role. The script creates a plan file in `terraform/`; remove it after the exercise. Students must complete the TODOs first and create `terraform/terraform.tfvars`.

## Technical notes

The Docker provider is pinned to `kreuzwerker/docker` 4.7.0. `terraform init` records the resolved provider in the lock file. No cloud provider, secrets, SSH, or extra Ansible collection is required. The provider uses the Docker CLI's default endpoint; non-default contexts may require `DOCKER_HOST` or provider configuration.
