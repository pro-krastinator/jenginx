#!/bin/bash
curl --max-time 5 -s http://$(curl -s icanhazip.com):8082 | grep 'Eventually I will understand Jenkins' >/dev/null 2>&1 || false ; echo $?
