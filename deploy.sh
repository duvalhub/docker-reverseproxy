#!/bin/bash

declare development=false
declare debug=false
while [[ $# -gt 0 ]]; do
case "$1" in
    --email) email="$2"; shift; shift;;
    --develoment) development="true"; shift; shift;;
    --debug) debug="true"; shift; shift;;
    *) usage; return 1 ;;
esac
done

