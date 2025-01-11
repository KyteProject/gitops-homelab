# Variables
inventory := "inventory/hosts.yml"
playbook_dir := "playbooks"

# Install dependencies
setup:
    python3 -m pip install -r requirements.txt
    ansible-galaxy collection install -r requirements.yml

# Lint Ansible files
lint:
    ansible-lint

# Deploy all apps
deploy-apps:
    ANSIBLE_DEPRECATION_WARNINGS=False ansible-playbook -i {{inventory}} {{playbook_dir}}/truenas-apps.yml --extra-vars "docker_apps=['minio']"

# Deploy specific app
deploy app:
    ANSIBLE_DEPRECATION_WARNINGS=False ansible-playbook -i {{inventory}} {{playbook_dir}}/truenas-apps.yml --extra-vars "docker_apps=[{{app}}]"
