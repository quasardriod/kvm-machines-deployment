#!/bin/bash

set -euo pipefail

# Default values
VERSION="43"
DISTRO="fedora"
CONTAINER_NAME="$DISTRO-toolbox-$VERSION"
HELP=0

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -d|--distro)
            DISTRO="$2"
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            HELP=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Display help
if [[ $HELP -eq 1 ]]; then
    cat << EOF
Usage: $0 [OPTIONS]

Create a $DISTRO toolbox container.

OPTIONS:
    -d, --distro DISTRO      Linux distribution (default: fedora)
    -v, --version VERSION    Distro version (default: 43)
    -n, --name NAME          Container name (default: fedora-toolbox-43)
    -h, --help              Show this help message

Examples:
    $0
    $0 --version 39 --name my-toolbox
EOF
    exit 0
fi

echo "Creating $DISTRO $VERSION toolbox container: $CONTAINER_NAME"

toolbox create --distro "$DISTRO" --release "$VERSION" "$CONTAINER_NAME"

echo "Toolbox container '$CONTAINER_NAME' created successfully!"