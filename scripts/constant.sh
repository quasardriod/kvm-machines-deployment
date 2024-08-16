#!/bin/bash

##### Block to color message output
# Color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
# Clear the color after that
clear='\033[0m'

function info(){
    printf "${cyan}$1${clear}"
}

function error(){
    printf "${red}$1${clear}"
}

function success(){
    printf "${green}$1${clear}"
}

function filtered_data(){
    printf "${magenta}$1${clear}"
}

function info_y(){
    printf "${yellow}$1${clear}"
}
#########
