# GoLD 💛

WordPress VIP **Go** **L**ocal **D**evelopment

## Requirements

* `docker`
* `docker-compose`
* `sudo`
* `tar`
* `curl`
* `sed`

## Getting Started

1. `git clone git@github.com:automattic/vip-gold`
2. `cp .env.sample .env`
3. Modify values in `.env`:
    1. `VIPGO_DOMAIN` = the domain name the local development environment should use
    2. `VIPGO_UPSTREAM_MEDIA_HOST` = for assets referenced in `/wp-content/uploads/*` that don't exist locally, a domain name that can be used to send requests for the assets to
    3. `VIPGO_REPOSITORY` = WPVIP structured project to `git clone` into `app/wp-content/`, defaults to WPVIP "skeleton"
4. `make init`
5. `make dev/up`
6. Update `/etc/hosts` to resolve your domain to loopback address, e.g. `127.0.0.1 wpvipgold.com`

## Commands

```
init           - sets up environment requirements/dependencies
dev/up         - alias of docker-compose up -d
dev/down       - alias of docker-compose down
dev/upgrade    - update all container images and provided mu-plugins

dev/reset      - WARNING! removes app/ and data/
dev/xdebug/on  - enable xdebug support
dev/xdebug/off - disable xdebug support
```
