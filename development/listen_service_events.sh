#!/bin/bash



docker events --filter type=service | while read event
do
    echo "$event"
done
