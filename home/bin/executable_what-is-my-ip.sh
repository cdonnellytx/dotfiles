#!/usr/bin/env bash

wget -o /dev/null -O - http://myexternalip.com/ | grep 'data-ip=' | sed -e 's/.*data-ip="//; s/".*//;'
