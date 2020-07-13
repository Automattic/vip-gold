.ONESHELL:
.NOTPARALLEL:

OS        ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
SELF      ?= $(MAKE)
SHELL      = /bin/bash

THIS_FILE := $(lastword $(MAKEFILE_LIST))
THIS_DIR  := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

## from https://github.com/buildroot/buildroot/blob/master/Makefile
THIS_VERS := $(MAKE_VERSION)
MIN_VERS  := 3.81
ifneq ($(firstword $(sort $(THIS_VERS) $(MIN_VERS))),$(MIN_VERS))
$(error GNU make >= $(MIN_VERS) is required, installed version is $(THIS_VERS))
endif

BOLD      = $(shell tput -Txterm bold)
RED       = $(shell tput -Txterm setaf 1)
GREEN     = $(shell tput -Txterm setaf 2)
YELLOW    = $(shell tput -Txterm setaf 3)
RESET     = $(shell tput -Txterm sgr0)
HR        = "////////////////////////////////////////////////////////////////////////////////"


PATCH := $(shell command -v patch 2>/dev/null)
SUDO := $(shell command -v sudo 2>/dev/null)
SED := $(shell command -v sed 2>/dev/null)
WGET := $(shell command -v wget 2>/dev/null)
TAR := $(shell command -v tar 2>/dev/null)
GREP := $(shell command -v grep 2>/dev/null)
PERL := $(shell command -v perl 2>/dev/null)
DOCKER := $(shell command -v docker 2>/dev/null)
DOCKER_COMPOSE := $(shell command -v docker-compose 2>/dev/null)
DOCKER_COMPOSE_OPTS := --log-level ERROR --compatibility

EXECUTABLES = PATCH SUDO SED WGET TAR DOCKER DOCKER_COMPOSE
K := $(foreach exec,$(EXECUTABLES),\
       $(if $($(exec)),OK,$(error "No $(exec) in PATH")))


define assert-set
  @[ -n "$($1)" ] || (echo "$(1) not defined in $(@)"; exit 1)
endef
define assert-unset
  @[ -z "$($1)" ] || (echo "$(1) should not be defined in $(@)"; exit 1)
endef

ifneq ($(shell test -e .env && echo -n HASENV),HASENV)
  $(error .env file is missing, copy .env.sample to .env, modify, and try again)
endif

MAKEENV   := $(shell bash -c "grep -vE '^\#' $(THIS_DIR)/.env | sed -e 's/=/?=/' -e '/^\$$/d' -e 's/^/export /;' > $(THIS_DIR)/.env.make")
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
	@echo "  dev/up         - alias of docker-compose up -d"
	@echo "  dev/down       - alias of docker-compose down"
	@echo "  dev/upgrade    - update all container images and provided mu-plugins"
	@echo "  dev/reset      - remove data/mariadb and run dev/upgrade"
	@echo "  dev/xdebug/on  - enable xdebug support"
	@echo "  dev/xdebug/off - disable xdebug support"
	@echo ""

.PHONY: init
init: $(DOCKER_COMPOSE)
	@$(SELF) -f $(THIS_FILE) -s init/mariadb
	@$(SELF) -f $(THIS_FILE) -s init/nginx
	@$(SELF) -f $(THIS_FILE) -s init/wordpress
	@echo "$(GREEN)READY:$(RESET) $(VIPGO_DOMAIN)"

.PHONY: init/mariadb
init/mariadb: $(DOCKER_COMPOSE) | data/mariadb
	@echo "$(GREEN)READY:$(RESET) data/mariadb"

data/mariadb:
	@echo "$(HR)"
	@echo "$(YELLOW)INIT: data/mariadb$(RESET)"
	@echo "$(HR)"

	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) up -d mariadb
	@iter=1; \
	max_wait=15; \
	while [[ $$iter != $$max_wait ]]; \
	do \
		res=$$($(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) logs mariadb 2>/dev/null | grep -cE "mysqld: ready for connections"); \
		if [[ "$$res" == "2" ]]; then \
			break; \
		fi; \
		echo "waiting... ($$iter/$$max_wait)"; \
		sleep 6; \
		iter=$$((iter+1)); \
	done; \
	if [[ $$iter == $$max_wait ]]; then \
		printf "%b" "$(RED)ERROR: mariadb didnt start successfully$(RESET)\n"; \
		exit 1; \
	fi;
	@$(SELF) -f $(THIS_FILE) -s dev/down
	@exit 0

.PHONY: init/nginx
init/nginx: $(DOCKER_COMPOSE) conf/nginx/conf.d/upstream-media-host
	@echo "$(GREEN)READY:$(RESET) conf/nginx/conf.d/upstream-media-host"

.PHONY: conf/nginx/conf.d/upstream-media-host
conf/nginx/conf.d/upstream-media-host: $(SED)
	@echo 'set $$upstream_media_host "$(VIPGO_UPSTREAM_MEDIA_HOST)";' > conf/nginx/conf.d/upstream-media-host

.PHONY: init/wordpress
init/wordpress: $(DOCKER_COMPOSE) | app/wp-content app/wp-content/mu-plugins
	@echo "$(GREEN)READY:$(RESET) app/wp-content"
	@echo "$(GREEN)READY:$(RESET) app/wp-content/mu-plugins"

app/wp-content: $(DOCKER_COMPOSE)
	@echo "$(HR)"
	@echo "$(YELLOW)INIT: app/wp-content$(RESET)"
	@echo "$(HR)"
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) up -d wordpress
	@iter=1; \
	max_wait=10; \
	while [[ $$iter != $$max_wait ]]; do \
		if stat ./app/wp-content &>/dev/null; then \
			break; \
		else \
			echo "waiting... ($$iter/$$max_wait)"; \
			sleep 1; \
			iter=$$((iter+1)); \
		fi; \
	done; \
	if [[ $$iter == $$max_wait ]]; then \
		printf "%b" "$(RED)ERROR: wordpress didnt start successfully$(RESET)\n"; \
		exit 1; \
	fi;
	@$(SELF) -f $(THIS_FILE) -s dev/down
	exit 0

app/wp-content/mu-plugins: $(TAR) $(PATCH) | data/wordpress/vip-go-mu-plugins.tar.gz
	@echo "$(HR)"
	@echo "$(YELLOW)INIT: app/wp-content/mu-plugins$(RESET)"
	@echo "$(HR)"
	mkdir -p app/wp-content/mu-plugins
	$(TAR) -xzvf data/wordpress/vip-go-mu-plugins.tar.gz --strip-components=1 -C app/wp-content/mu-plugins
	$(PATCH) -F0 -p0 -d "$(THIS_DIR)" -i "$(THIS_DIR)/dev-env.diff"

data/wordpress/vip-go-mu-plugins.tar.gz: $(WGET)
	mkdir -p data/wordpress
	$(WGET) -O data/wordpress/vip-go-mu-plugins.tar.gz $(VIPGO_MUPLUGINS)

.PHONY: /etc/hosts
/etc/hosts:
	@$(GREP) -qxF '127.0.0.1\s+$(VIPGO_DOMAIN)' /etc/hosts \
		|| sudo $(PERL) -i -pe "eof && do{print qq[\$$_\n# VIP Go Local Environment\n127.0.0.1 $(VIPGO_DOMAIN)\n]; exit;}" /etc/hosts

.PHONY: dev/upgrade
dev/upgrade: $(DOCKER_COMPOSE)
	@$(SELF) -f $(THIS_FILE) -s dev/down
	@$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) pull -q
	@rm -f app/index.php app/wp-includes/version.php
	@rm -rf data/wordpress/vip-go-mu-plugins.tar.gz app/wp-content/mu-plugins
	@$(SELF) -f $(THIS_FILE) -s dev/up

.PHONY: dev/reset
dev/reset: $(DOCKER_COMPOSE)
	@rm -rf data/mariadb
	@$(SELF) -f $(THIS_FILE) -s dev/upgrade

.PHONY: dev/up
dev/up: $(DOCKER_COMPOSE) | init
	@echo "$(HR)"
	@echo "$(YELLOW)STARTING ENVIRONMENT$(RESET)"
	@echo "$(HR)"
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) up -d

.PHONY: dev/down
dev/down: $(DOCKER_COMPOSE)
	@echo "$(HR)"
	@echo "$(YELLOW)STOPPING ENVIRONMENT$(RESET)"
	@echo "$(HR)"
	$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) down

.PHONY: dev/xdebug/on
dev/xdebug/on: $(DOCKER_COMPOSE) $(DOCKER)
	@$(DOCKER) cp conf/wordpress/conf.d/docker-php-ext-xdebug.ini \
		$$($(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) ps -q wordpress):/usr/local/etc/php/conf.d/
	@$(DOCKER_COMPOSE) restart wordpress

.PHONY: dev/xdebug/off
dev/xdebug/off: $(DOCKER_COMPOSE) $(DOCKER)
	@$(DOCKER_COMPOSE) $(DOCKER_COMPOSE_OPTS) exec -T wordpress \
		sh -c "rm -fv /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini"
	@$(DOCKER_COMPOSE) restart wordpress
