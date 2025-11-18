#!/bin/bash

chown -R ${PUID}:${PGID} /opt/mylist/

umask ${UMASK}

if [ "$1" = "version" ]; then
  ./mylist version
else
  exec su-exec ${PUID}:${PGID} ./mylist server --no-prefix
fi