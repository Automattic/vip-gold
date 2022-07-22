.ONESHELL:
.NOTPARALLEL:

OS        ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
SELF      ?= $(MAKE)
SHELL      = /bin/bash

THIS_FILE := $(lastword $(MAKEFILE_LIST))
THIS_DIR  := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

## from https://github.com/buildroot/buildroot/blob/master/Makefile
MAKE_VERS := $(MAKE_VERSION)
MAKE_MIN_VERS  := 3.81
ifneq ($(firstword $(sort $(MAKE_VERS) $(MAKE_MIN_VERS))),$(MAKE_MIN_VERS))
$(error GNU make >= $(MAKE_MIN_VERS) is required, installed version is $(MAKE_VERS))
endif

BOLD      = $(shell tput -Txterm bold)
RED       = $(shell tput -Txterm setaf 1)
GREEN     = $(shell tput -Txterm setaf 2)
YELLOW    = $(shell tput -Txterm setaf 3)
BLUE      = $(shell tput -Txterm setaf 4)
RESET     = $(shell tput -Txterm sgr0)

SUDO := $(shell command -v /usr/bin/sudo 2>/dev/null)
SED := $(shell command -v /usr/bin/sed 2>/dev/null)
CURL := $(shell command -v /usr/bin/curl 2>/dev/null)
TAR := $(shell command -v /usr/bin/tar 2>/dev/null)
GREP := $(shell command -v /usr/bin/grep 2>/dev/null)
PERL := $(shell command -v /usr/bin/perl 2>/dev/null)
SECURITY := $(shell command -v /usr/bin/security 2>/dev/null)
GIT := $(shell command -v git 2>/dev/null)
DOCKER := $(shell command -v docker 2>/dev/null)
OPENSSL := $(shell command -v openssl 2>/dev/null)

EXECUTABLES = SUDO SED CURL TAR GREP PERL SECURITY GIT DOCKER OPENSSL
K := $(foreach exec,$(EXECUTABLES),\
       $(if $($(exec)),OK,$(error "No $(exec) in $$PATH")))

OPENSSL_VERS      := $(shell $(OPENSSL) version | $(PERL) -n -e'/^OpenSSL ([0-9.]+)/ && print $$1')
OPENSSL_MIN_VERS  := 1.1.1
ifneq ($(firstword $(sort $(OPENSSL_VERS) $(OPENSSL_MIN_VERS))),$(OPENSSL_MIN_VERS))
$(warning OpenSSL >= $(OPENSSL_MIN_VERS) is required, installed version is $(OPENSSL_VERS))
$(warning Run 'brew install openssl@1.1' and follow instructions to update $$PATH)
$(error Minimum requirements not met)
endif

define assert-set
  @[ -n "$($1)" ] || (echo "$(1) not defined in $(@)"; exit 1)
endef
define assert-unset
  @[ -z "$($1)" ] || (echo "$(1) should not be defined in $(@)"; exit 1)
endef

ifneq ($(shell test -e .env && echo -n HASENV),HASENV)
  $(error .env file is missing, copy .env.sample to .env, modify, and try again)
endif

MAKEENV   := $(shell bash -c "$(GREP) -vE '^\#' $(THIS_DIR)/.env | sed -e 's/=/?=/' -e '/^\$$/d' -e 's/^/export /;' > $(THIS_DIR)/.env.make")
include .env.make

default:: help
	@exit 0

.PHONY: help
help:
	@echo "$(BOLD)usage:$(RESET)"
	@echo "  make <command>"
	@echo ""
	@echo "$(BOLD)commands:$(RESET)"
	@echo "  init           - sets up environment requirements/dependencies"
	@echo "  dev/up         - alias of docker compose up -d"
	@echo "  dev/down       - alias of docker compose down"
	@echo "  dev/upgrade    - update all container images and provided mu-plugins"
	@echo "  dev/restart    - stop and start the environment"
	@echo ""
	@echo "  dev/reset      - $(YELLOW)WARNING!$(RESET) removes app/ and data/"
	@echo "  dev/xdebug/on  - enable xdebug support"
	@echo "  dev/xdebug/off - disable xdebug support"
	@echo ""
	@echo "  hosts/add      - add VIPGO_DOMAIN to /etc/hosts"
	@echo "  hosts/remove   - remove VIPGO_DOMAIN from /etc/hosts"
	@echo ""
	@echo "  tls/ca         - generate certificate authority, add to keychain"
	@echo "  tls/domain     - generate VIPGO_DOMAIN cert + key"
	@echo "  tls/reset      - remove certificate authority and VIPGO_DOMAIN cert+key"
	@echo ""
	@echo "  SQL=file.sql db/import - imports file.sql into mariadb instance"
	@echo "  db/export - exports mariadb DB into VIPGO_WP_DB_NAME.sql"
	@echo ""

.PHONY: init
init: $(DOCKER)
	@echo "$(BLUE)[+] Initialize Development Environment$(RESET)"
	@$(SELF) -f $(THIS_FILE) -s init/wordpress
	@$(SELF) -f $(THIS_FILE) -s init/nginx
	@$(SELF) -f $(THIS_FILE) -s init/mariadb
	@echo "$(GREEN)[+] DONE! run 'make dev/up' to start the environment$(RESET)"

.PHONY: init/mariadb
init/mariadb: $(DOCKER) | data/mariadb
	@echo "$(BLUE) ⠿ Initialized: data/mariadb$(RESET)"

data/mariadb:
	@echo "[+] Initialize: data/mariadb"

	@mkdir -p data/mariadb
	$(DOCKER) compose up -d mariadb
	@iter=1; \
	max_wait=15; \
	while [[ $$iter != $$max_wait ]]; \
	do \
		res=$$($(DOCKER) compose logs mariadb 2>/dev/null | $(GREP) -cE "mysqld: ready for connections"); \
		if [[ "$$res" == "2" ]]; then \
			break; \
		fi; \
		echo "   waiting... ($$iter/$$max_wait)"; \
		sleep 6; \
		iter=$$((iter+1)); \
	done; \
	if [[ $$iter == $$max_wait ]]; then \
		printf "%b" "$(RED)ERROR: mariadb didnt start successfully$(RESET)\n"; \
		exit 1; \
	fi;
	sleep 3;
	@$(SELF) -f $(THIS_FILE) -s dev/down
	@exit 0

.PHONY: init/nginx
init/nginx: $(DOCKER) conf/nginx/conf.d/upstream-media-host
	mkdir -p data/nginx
	@echo "$(BLUE) ⠿ Initialized: data/nginx$(RESET)"

conf/nginx/conf.d/upstream-media-host:
	@echo 'set $$upstream_media_host "$(VIPGO_UPSTREAM_MEDIA_HOST)";' > conf/nginx/conf.d/upstream-media-host
	@echo "$(BLUE) ⠿ Initialized: conf/nginx$(RESET)"

.PHONY: init/wordpress
init/wordpress: $(DOCKER) | app/wp-content app/wp-content/mu-plugins
	@echo "$(BLUE) ⠿ Initialized: app/wp-content/mu-plugins$(RESET)"
	@echo "$(BLUE) ⠿ Initialized: app/wp-content$(RESET)"

app/wp-content/mu-plugins: $(TAR) | data/wordpress/vip-go-mu-plugins.tar.gz
	@echo "[+] Initialize: app/wp-content/mu-plugins"
	mkdir -p app/wp-content/mu-plugins
	$(TAR) -xzvf data/wordpress/vip-go-mu-plugins.tar.gz --strip-components=1 -C app/wp-content/mu-plugins

app/wp-content: $(DOCKER)
	@echo "[+] Initialize: app/wp-content"
	$(GIT) clone "$(VIPGO_REPOSITORY)" app/wp-content
	mkdir -p app/wp-content/{client-mu-plugins,images,languages,plugins,themes,vip-config,uploads}

data/wordpress/vip-go-mu-plugins.tar.gz: $(CURL)
	mkdir -p data/wordpress
	$(CURL) -sL --fail -o data/wordpress/vip-go-mu-plugins.tar.gz $(VIPGO_MUPLUGINS)

.PHONY: dev/upgrade
dev/upgrade: $(DOCKER)
	@$(SELF) -f $(THIS_FILE) -s dev/down

	@echo "[+] Update: GoLD"
	@$(GIT) pull

	@echo "[+] Update: GoLD Docker Images"
	@$(DOCKER) compose pull -q

	@rm -rf data/wordpress/vip-go-mu-plugins.tar.gz app/wp-content/mu-plugins
	@$(SELF) -f $(THIS_FILE) -s app/wp-content/mu-plugins
	@$(SELF) -f $(THIS_FILE) -s dev/up

.PHONY: dev/reset
dev/reset: $(DOCKER)
	@$(SELF) -f $(THIS_FILE) -s dev/down
	@rm -rf data app .env .env.make
	@echo "$(BLUE) ⠿ Deleted: app/$(RESET)"
	@echo "$(BLUE) ⠿ Deleted: data/$(RESET)"
	@echo "$(BLUE) ⠿ Deleted: .env$(RESET)"
	@echo "$(YELLOW)[!] To re-initialize:"
	@echo " - Run: cp .env.sample .env"
	@echo " - Reconfigure .env"
	@echo " - Run: make init$(RESET)"
	@echo "$(GREEN)[+] DONE!$(RESET)"

.PHONY: dev/up
dev/up: $(DOCKER)
	@echo "$(BLUE)[+] Starting Development Environment$(RESET)"
	@$(SELF) -f $(THIS_FILE) -s tls/domain
	@$(DOCKER) compose up -d
	@$(SELF) -f $(THIS_FILE) -s hosts/add

.PHONY: dev/down
dev/down: $(DOCKER)
	@echo "$(BLUE)[+] Stopping Development Environment$(RESET)"
	@$(DOCKER) compose down
	@echo -n "$(BLUE)[+] Removing volume: $(RESET)"
	@$(DOCKER) volume rm --force "$$(basename $${PWD})_wp"
	@$(SELF) -f $(THIS_FILE) -s hosts/remove

.PHONY: dev/restart
dev/restart: $(DOCKER)
	@$(SELF) -f $(THIS_FILE) -s dev/down
	@$(SELF) -f $(THIS_FILE) -s dev/up

.PHONY: dev/xdebug/on
dev/xdebug/on: $(DOCKER)
	@$(PERL) -pi -e 's/^\;zend_extension/zend_extension/' conf/wordpress/conf.d/docker-php-ext-xdebug.ini
	@$(DOCKER) compose restart wordpress

.PHONY: dev/xdebug/off
dev/xdebug/off: $(DOCKER)
	@$(PERL)  -pi -e 's/^zend_extension/\;zend_extension/' conf/wordpress/conf.d/docker-php-ext-xdebug.ini
	@$(DOCKER) compose restart wordpress

.PHONY: hosts/add
hosts/add:
	@echo "$(BLUE)[+] Updating /etc/hosts (enter password if prompted)$(RESET)"
	@$(GREP) -qE '^127.0.0.1\s+$(VIPGO_DOMAIN)' /etc/hosts \
		|| $(SUDO) $(PERL) -i -pe "eof && do{print qq[\$$_\n127.0.0.1 $(VIPGO_DOMAIN)]; exit;}" /etc/hosts

.PHONY: hosts/remove
hosts/remove:
	@echo "$(BLUE)[+] Updating /etc/hosts (enter password if prompted)$(RESET)"
	@$(GREP) -qvE '^127.0.0.1\s+$(VIPGO_DOMAIN)' /etc/hosts \
		&& $(SUDO) $(PERL) -0777 -i -pe "s/\n127.0.0.1\s+$(VIPGO_DOMAIN)\$$//gsm" /etc/hosts

.PHONY: tls/ca
tls/ca: $(SUDO) $(SECURITY) | $(HOME)/.local/share/vip-gold/ca.key $(HOME)/.local/share/vip-gold/ca.crt
	@echo "$(BLUE) ⠿ Initialized: $(HOME)/.local/share/vip-gold/ca.key$(RESET)"
	@echo "$(BLUE) ⠿ Initialized: $(HOME)/.local/share/vip-gold/ca.crt$(RESET)"
	@echo "$(BLUE)[+] Certificate Authority exists in login.keychain-db$(RESET)"

$(HOME)/.local/share/vip-gold/ca.key: $(OPENSSL)
	@echo "[+] Initialize: $(@)"
	@mkdir -pv $(shell dirname $@)
	$(OPENSSL) genrsa -out "$(@)" 2048

$(HOME)/.local/share/vip-gold/ca.crt: $(OPENSSL) | $(HOME)/.local/share/vip-gold/ca.key
	@echo "[+] Initialize: $(@)"
	$(OPENSSL) req \
    -config $${PWD}/conf/nginx/certs/openssl.cnf \
    -x509 \
    -new \
    -nodes \
    -key "$(HOME)/.local/share/vip-gold/ca.key" \
    -days 3650 \
    -out "$(@)" \
    -extensions v3_ca \
    -subj "/CN=VIP Go Local Development (GoLD)"

	-$(SUDO) $(SECURITY) delete-certificate -c "VIP Go Local Development (GoLD)"
	@echo

	$(SUDO) $(SECURITY) add-trusted-cert \
		-d \
		-r trustRoot \
		-k $(HOME)/Library/Keychains/login.keychain-db \
		$(@)

	@echo "$(YELLOW)[!] If using Mozilla Firefox:"
	@echo " - Navigate to: about:config"
	@echo " - Search: security.enterprise_roots.enabled"
	@echo " - Double click: security.enterprise_roots.enabled to set to 'true'"
	@echo " - Restart: Mozilla Firefox$(RESET)"
	@echo "$(GREEN)[+] DONE!$(RESET)"

.PHONY: tls/domain
tls/domain: tls/ca \
	conf/nginx/certs/$(VIPGO_DOMAIN).key \
	conf/nginx/certs/$(VIPGO_DOMAIN).csr \
	conf/nginx/certs/$(VIPGO_DOMAIN).crt
	@echo "$(BLUE) ⠿ Initialized: conf/nginx/certs/$(VIPGO_DOMAIN).key$(RESET)"
	@echo "$(BLUE) ⠿ Initialized: conf/nginx/certs/$(VIPGO_DOMAIN).csr$(RESET)"
	@echo "$(BLUE) ⠿ Initialized: conf/nginx/certs/$(VIPGO_DOMAIN).crt$(RESET)"
	@echo "$(BLUE)[+] Generated TLS certificate for $(VIPGO_DOMAIN)$(RESET)"

conf/nginx/certs/$(VIPGO_DOMAIN).key: $(OPENSSL)
	@echo "[+] Initialize: $(@)"
	$(OPENSSL) genrsa -out $(@) 2048

conf/nginx/certs/$(VIPGO_DOMAIN).csr: $(OPENSSL) | conf/nginx/certs/$(VIPGO_DOMAIN).key
	@echo "[+] Initialize: $(@)"
	$(OPENSSL) req \
		-new \
		-key $${PWD}/conf/nginx/certs/$(VIPGO_DOMAIN).key \
		-out $(@) \
		-subj "/CN=$(VIPGO_DOMAIN)" \
		-addext "subjectAltName = DNS:$(VIPGO_DOMAIN)" \
		-config $${PWD}/conf/nginx/certs/openssl.cnf

conf/nginx/certs/$(VIPGO_DOMAIN).crt: $(OPENSSL) | conf/nginx/certs/$(VIPGO_DOMAIN).csr
	@echo "[+] Initialize: $(@)"
	$(OPENSSL) x509 \
		-req \
		-in conf/nginx/certs/$(VIPGO_DOMAIN).csr \
		-CA $(HOME)/.local/share/vip-gold/ca.crt \
		-CAkey $(HOME)/.local/share/vip-gold/ca.key \
		-CAcreateserial \
		-out $(@) \
    -days 365 \
    -extensions v3_req \
    -extensions SAN \
    -extfile <( \
    	cat $${PWD}/conf/nginx/certs/openssl.cnf \
    	<(printf "\n[SAN]\nsubjectAltName=DNS:$(VIPGO_DOMAIN)") \
    )

.PHONY: tls/reset
tls/reset: $(SUDO) $(SECURITY)
	@$(SELF) -f $(THIS_FILE) -s dev/down

	@rm -fv \
		$(HOME)/.local/share/vip-gold/ca.key \
		$(HOME)/.local/share/vip-gold/ca.crt \
		$${PWD}/conf/nginx/certs/$(VIPGO_DOMAIN).key \
		$${PWD}/conf/nginx/certs/$(VIPGO_DOMAIN).csr \
		$${PWD}/conf/nginx/certs/$(VIPGO_DOMAIN).crt
	
	-$(SUDO) $(SECURITY) delete-certificate -c "VIP Go Local Development (GoLD)"
	@echo

	@echo "$(GREEN)[+] DONE!$(RESET)"

.PHONY: db/import
db/import: $(DOCKER)
	$(call assert-set,SQL)

	@if [ ! -f $(SQL) ]; then \
	  echo "$(SQL) doesn't exist!"; \
	  exit 1; \
	fi;

	@echo "[+] Importing: $(SQL)"
	@$(DOCKER) compose exec \
		--no-TTY \
		mariadb \
		mysql \
			-uroot \
			-p$(VIPGO_MYSQL_ROOT_PASSWORD)\
			$(VIPGO_WP_DB_NAME) \
			< $(SQL)

	@echo "$(GREEN)[+] DONE!$(RESET)"

.PHONY: db/export
db/export: $(DOCKER)
	@echo "[+] Exporting: $(VIPGO_WP_DB_NAME).sql"
	@$(DOCKER) compose exec \
		mariadb \
		mysqldump \
		  --opt \
			-uroot \
			-p$(VIPGO_MYSQL_ROOT_PASSWORD)\
			$(VIPGO_WP_DB_NAME) \
			> $(VIPGO_WP_DB_NAME).sql

	@echo "$(GREEN)[+] DONE!$(RESET)"