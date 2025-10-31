# Use bash for any 'source' etc.
SHELL := /bin/bash

# --- ENV helpers ---
ENV_FILE := compose/.env
ENV_SAMPLE := compose/.env.sample
REQ_VARS := TZ PI_USER NGINX_DDNS_FQDN NGINX_CF_ZONE NGINX_CF_RECORD WG_PORT WG_NET WG_SERVER_CIDR CAM1_IP CAM1_USER CAM1_PASS

VAULT_ID ?= main@prompt
VERBOSITY ?= -vvv

env-init:
	@test -f $(ENV_FILE) || { cp $(ENV_SAMPLE) $(ENV_FILE); echo "Created $(ENV_FILE) from sample."; }

env-print:
	@echo "Required variables:"
	@for V in $(REQ_VARS); do \
	  VAL="$${!V}"; \
	  if [ -z "$$VAL" ]; then printf "  %-20s %s\n" "$$V" "(MISSING)"; else printf "  %-20s %s\n" "$$V" "$$VAL"; fi; \
	done

# Load compose/.env for all targets if present
ifneq (,$(wildcard compose/.env))
  include compose/.env
  export
endif

# ------- Defaults you can override on the command line -------
ANSIBLE_INV        ?= ansible/inventory/hosts.ini
PLAYBOOK           ?= ansible/site.yml
ANSIBLE_VAULT_ID   ?= main
ANSIBLE_VAULT_FILE ?= ansible/inventory/group_vars/pi/vault.yml
PYTHON             ?= python3
VENV               ?= .venv
BIN                := $(VENV)/bin

# Flutter dev settings
DEBUG_NETWORK      ?= # Leave empty for production, set to 'wifi'/'vpn'/'internet' for dev

.PHONY: venv init lint simulate deploy vault-edit clean env-check env-init env-print sim-build sim-up sim-test sim-clean sim-logs ssh-keygen flutter-dev flutter-build flutter-deploy

venv:
	@echo "[venv] Creating venv and installing Ansible…"
	$(PYTHON) -m venv $(VENV) || true
	$(BIN)/pip install -U pip
	$(BIN)/pip install -U ansible ansible-lint

ssh-keygen: ## Generate SSH key if it doesn't exist
	@if [ ! -f ~/.ssh/id_ed25519 ]; then \
		echo "[ssh-keygen] Creating new SSH key..."; \
		ssh-keygen -t ed25519 -C "ansible@crooked-sentry" -f ~/.ssh/id_ed25519 -N ""; \
	else \
		echo "[ssh-keygen] SSH key already exists at ~/.ssh/id_ed25519"; \
	fi

init: ssh-keygen venv ## Initialize fresh Raspberry Pi (remove old SSH key, copy new key)
	@echo "[init] Setting up SSH access to fresh Pi..."
	@read -p "Enter Pi IP address [192.168.0.200]: " PI_IP; \
	PI_IP=$${PI_IP:-192.168.0.200}; \
	read -p "Enter Pi username [bossbitch]: " PI_USER; \
	PI_USER=$${PI_USER:-bossbitch}; \
	echo "[init] Removing old SSH host key..."; \
	ssh-keygen -R $$PI_IP 2>/dev/null || true; \
	echo "[init] Copying SSH key to Pi..."; \
	ssh-copy-id -i ~/.ssh/id_ed25519.pub $$PI_USER@$$PI_IP; \
	echo "[init] Testing Ansible connection..."; \
	$(BIN)/ansible -i $(ANSIBLE_INV) pi -m ping --vault-id $(VAULT_ID); \
	echo "[init] Generating WireGuard keys..."; \
	ssh $$PI_USER@$$PI_IP 'sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y wireguard-tools > /dev/null 2>&1'; \
	ssh $$PI_USER@$$PI_IP 'wg genkey | tee /tmp/server_private.key | wg pubkey > /tmp/server_public.key'; \
	ssh $$PI_USER@$$PI_IP 'wg genkey | tee /tmp/household_private.key | wg pubkey > /tmp/household_public.key'; \
	echo "wireguard_server_private_key: \"$$(ssh $$PI_USER@$$PI_IP 'cat /tmp/server_private.key')\"" > /tmp/wg_keys.yml; \
	echo "wireguard_household_public_key: \"$$(ssh $$PI_USER@$$PI_IP 'cat /tmp/household_public.key')\"" >> /tmp/wg_keys.yml; \
	echo "wireguard_household_private_key: \"$$(ssh $$PI_USER@$$PI_IP 'cat /tmp/household_private.key')\"" >> /tmp/wg_keys.yml; \
	ssh $$PI_USER@$$PI_IP 'rm -f /tmp/*_*.key'; \
	echo ""; \
	echo "✅ WireGuard keys saved to /tmp/wg_keys.yml"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  1. Run: make vault-add-keys"; \
	echo "  2. Run: make deploy"

vault-add-keys: venv ## Add generated WireGuard keys to vault (run after init)
	@if [ ! -f /tmp/wg_keys.yml ]; then \
		echo "❌ No keys found. Run 'make init' first."; \
		exit 1; \
	fi
	@echo "[vault] Decrypting vault..."
	@$(BIN)/ansible-vault decrypt --vault-id $(ANSIBLE_VAULT_ID)@prompt $(ANSIBLE_VAULT_FILE)
	@echo "[vault] Removing old WireGuard keys if present..."
	@grep -v "wireguard_server_private_key\|wireguard_household_public_key\|wireguard_household_private_key" $(ANSIBLE_VAULT_FILE) > $(ANSIBLE_VAULT_FILE).tmp || true
	@mv $(ANSIBLE_VAULT_FILE).tmp $(ANSIBLE_VAULT_FILE)
	@echo "[vault] Adding new WireGuard keys..."
	@cat /tmp/wg_keys.yml >> $(ANSIBLE_VAULT_FILE)
	@echo "[vault] Re-encrypting vault..."
	@$(BIN)/ansible-vault encrypt --vault-id $(ANSIBLE_VAULT_ID)@prompt $(ANSIBLE_VAULT_FILE)
	@rm /tmp/wg_keys.yml
	@echo "✅ WireGuard keys added to vault!"
	@echo ""
	@echo "Verify with: make vault-edit"

lint: venv
	@echo "[lint] ansible-lint…"
	$(BIN)/ansible-lint ansible || true

validate:
	@if [ -f $(ENV_FILE) ]; then set -a; . $(ENV_FILE); set +a; fi
	$(BIN)/bash scripts/validate.sh
	$(MAKE) env-check

simulate: venv
	@echo "[simulate] Check mode…"
	$(BIN)/ansible-playbook -i $(ANSIBLE_INV) $(VERBOSITY) $(PLAYBOOK) --check \
	  --vault-id $(VAULT_ID) \
	  -e ansible_python_interpreter=/usr/bin/python3

deploy: venv
	@echo "[deploy] Applying changes…"
	$(BIN)/ansible-playbook -i $(ANSIBLE_INV) $(PLAYBOOK) \
	  --vault-id $(VAULT_ID) \
	  -e ansible_python_interpreter=/usr/bin/python3

vault-edit: venv
	@echo "[vault] Editing: $(ANSIBLE_VAULT_FILE)"
	$(BIN)/ansible-vault edit --vault-id $(ANSIBLE_VAULT_ID)@prompt \
	  $(ANSIBLE_VAULT_FILE)

env-check:
	@missing=0; \
	for V in $(REQ_VARS); do \
	  VAL="$${!V}"; \
	  if [ -z "$$VAL" ]; then echo "Missing $$V"; missing=1; fi; \
	done; \
	[ $$missing -eq 0 ] || { echo "Fix missing env vars in $(ENV_FILE)"; exit 1; }

clean:
	@echo "[clean] Removing venv…"
	rm -rf $(VENV)

# === SIMULATION TARGETS ===

sim-build:
	@echo "[sim-build] Building Raspberry Pi simulation container..."
	cd simulation && docker compose build --no-cache

sim-up: sim-build
	@echo "[sim-up] Starting simulation environment..."
	cd simulation && docker compose up -d
	@echo "Waiting for services to start..."
	sleep 10
	@echo "Pi simulation available at:"
	@echo "  SSH: ssh pi@localhost -p 2222 (password: raspberry)"
	@echo "  HTTP: http://localhost:8080"
	@echo "  Frigate: http://localhost:15000"

sim-deploy: sim-up
	@echo "[sim-deploy] Deploying crooked-sentry to simulation..."
	cp ansible/inventory/hosts.ini ansible/inventory/hosts-sim.ini
	sed -i.bak 's/ansible_host=.*/ansible_host=localhost ansible_port=2222/' ansible/inventory/hosts-sim.ini
	$(BIN)/ansible-playbook -i ansible/inventory/hosts-sim.ini $(PLAYBOOK) \
	  --vault-id $(VAULT_ID) \
	  -e ansible_python_interpreter=/usr/bin/python3 \
	  -e ansible_ssh_common_args='-o StrictHostKeyChecking=no'

sim-test:
	@echo "[sim-test] Testing all three requirements..."
	@echo ""
	@echo "=== REQUIREMENT 1: Camera functionality ==="
	docker exec crooked-sentry-pi-sim curl -s http://localhost:15000/api/version || echo "Frigate not ready"
	@echo ""
	@echo "=== REQUIREMENT 2: LAN/VPN user access (trusted) ==="
	curl -s -I http://localhost:8080/ | head -1 || echo "HTTP test failed"
	curl -s -I http://localhost:8080/household.conf | head -1 || echo "Household config test failed"
	@echo ""
	@echo "=== REQUIREMENT 3: External user access (untrusted) ==="
	docker exec test-client curl -s -I http://pi-simulator/ | head -1 || echo "External test failed"
	@echo ""
	@echo "Run 'make sim-logs' to see detailed logs"

sim-logs:
	@echo "[sim-logs] Container logs..."
	cd simulation && docker compose logs -f

sim-shell:
	@echo "[sim-shell] Connecting to simulation Pi..."
	docker exec -it crooked-sentry-pi-sim /bin/bash

sim-clean:
	@echo "[sim-clean] Stopping and removing simulation..."
	cd simulation && docker compose down -v
	docker buildx rm sim-builder 2>/dev/null || true
	rm -f ansible/inventory/hosts-sim.ini ansible/inventory/hosts-sim.ini.bak
	rm -f test_when_online.sh

sim-reset: sim-clean sim-up

# === FLUTTER TARGETS ===

flutter-dev: ## Run Flutter app in dev mode with DEBUG_NETWORK override (e.g., make flutter-dev DEBUG_NETWORK=wifi)
	@echo "[flutter-dev] Running Flutter app in Chrome with DEBUG_NETWORK=$(DEBUG_NETWORK)..."
	@cd home_dashboard && \
	if [ -n "$(DEBUG_NETWORK)" ]; then \
		flutter run -d chrome --dart-define=DEBUG_NETWORK=$(DEBUG_NETWORK); \
	else \
		flutter run -d chrome; \
	fi

flutter-build: ## Build Flutter web app for production (no debug overrides)
	@echo "[flutter-build] Building Flutter web app for production..."
	@cd home_dashboard && flutter build web --release

flutter-deploy: flutter-build ## Build and deploy Flutter app to Pi (via Ansible)
	@echo "[flutter-deploy] Deploying Flutter web app to Pi..."
	@echo "TODO: Add Ansible task to copy home_dashboard/build/web to Pi nginx root"
