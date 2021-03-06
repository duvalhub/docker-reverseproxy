#!/bin/bash

set -e

while true; do 
    date;

    for domain in $@; do
        echo "$domain"
        for pro in http https; do 
            curl -s -k -I $pro://$domain | head -n 1 | xargs echo "$pro: "; 
        done; 
        echo
    done

    sleep 2; 
    
    printf "\n\n\n"; 
done