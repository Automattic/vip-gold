# GoLD 💛

WordPress VIP **Go** **L**ocal **D**evelopment

## Requirements

* `docker`
* `docker-compose`
* `sudo`
* `patch`
* `tar`
* `wget`
* `sed`

## Getting Started

1. `git clone git@github.com:automattic/vip-gold`
2. `cp .env.sample .env`
3. Modify values in `.env`:
    1. `VIPGO_DOMAIN` = the domain name the local development environment should use
    2. `VIPGO_UPSTREAM_MEDIA_HOST` = for assets referenced in `/wp-content/uploads/*` that don't exist locally, a domain name that can be used to send requests for the assets to
4. `make dev/up`

## Commands

```
init           - sets up environment requirements/dependencies
dev/up         - alias of docker-compose up -d
dev/down       - alias of docker-compose down
dev/upgrade    - update all container images and provided mu-plugins
dev/reset      - remove data/mariadb and run dev/upgrade
dev/xdebug/on  - enable xdebug support
dev/xdebug/off - disable xdebug support
```
