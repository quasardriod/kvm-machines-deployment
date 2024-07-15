#!/bin/bash

if ! which yq > /dev/null 2>&1;then
    sudo dnf install yq -y -q
fi