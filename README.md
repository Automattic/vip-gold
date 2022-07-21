# GoLD 💛

WordPress VIP **Go** **L**ocal **D**evelopment

## Requirements

* `docker` (with `compose`)
* `sudo`
* `tar`
* `curl`
* `sed`
* `perl`
* `openssl`

## Getting Started

1. `git clone https://github.com/automattic/vip-gold && cd vip-gold`
2. `cp .env.sample .env`
3. Modify values in `.env`:
    1. `VIPGO_DOMAIN` = the domain name the local development environment should use
    2. `VIPGO_UPSTREAM_MEDIA_HOST` = for assets referenced in `/wp-content/uploads/*` that don't exist locally, a domain name that can be used to send requests for the assets to
    3. `VIPGO_REPOSITORY` = WPVIP structured project to `git clone` into `app/wp-content/`, defaults to WPVIP "skeleton"
    4. `VIPGO_PHP_VERSION` = PHP version to use, defaults to `latest`
4. `make init`
5. `make dev/up`

## Commands

```
init           - sets up environment requirements/dependencies
dev/up         - alias of docker compose up -d
dev/down       - alias of docker compose down
dev/upgrade    - update all container images and provided mu-plugins
dev/restart    - stop and start the environment

dev/reset      - WARNING! removes app/ and data/
dev/xdebug/on  - enable xdebug support
dev/xdebug/off - disable xdebug support

hosts/add      - add VIPGO_DOMAIN to /etc/hosts
hosts/remove   - remove VIPGO_DOMAIN from /etc/hosts

tls/ca         - generate certificate authority, add to keychain
tls/domain     - generate VIPGO_DOMAIN cert + key
tls/reset      - remove certificate authority and VIPGO_DOMAIN cert+key
```
