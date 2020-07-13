#!/usr/bin/env bash
exec /bin/bash -c 'trap : TERM INT; sleep 99999 & wait'