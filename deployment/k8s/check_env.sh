#!/bin/bash
# Set color variables for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


if ! command -v colima &> /dev/null; then
    echo "Colima is not installed"
else
    echo "Colima is installed"
fi

if ! command -v orb &> /dev/null; then
    echo "Orb is not installed"
else
    echo "Orb is installed"
fi

if ! command -v docker &> /dev/null; then
    echo "Docker cli is not installed"
    exit 1
else
    echo -e "Docker cli is installed:"; docker version
fi

if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed"
    exit 1
else
    echo -e "kubectl is installed:"; kubectl version
fi

if ! command -v helm &> /dev/null; then
    echo "helm is not installed"
    exit 1
else
    echo -e "helm is installed:"; helm version
fi

