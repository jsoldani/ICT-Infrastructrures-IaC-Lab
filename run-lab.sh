#!/usr/bin/env sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

terraform -chdir="$ROOT_DIR/terraform" init
terraform -chdir="$ROOT_DIR/terraform" validate
terraform -chdir="$ROOT_DIR/terraform" plan -out="$ROOT_DIR/terraform/lab.tfplan"
terraform -chdir="$ROOT_DIR/terraform" apply "$ROOT_DIR/terraform/lab.tfplan"
ansible-playbook -i "$ROOT_DIR/ansible/inventory.ini" "$ROOT_DIR/ansible/site.yml"
printf '%s\n' 'Lab deployed at http://localhost:8080'
