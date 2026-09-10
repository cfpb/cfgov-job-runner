#!/bin/sh
#
# Test script for the built Docker image.
#
# docker run --rm \
#   -v "$PWD/test-image.sh:/test-image.sh:ro" \
#   cfgov-job-runner:latest \
#   /test-image.sh

FAILURES=0

check() {
    if output=$(eval "$2" 2>&1); then
        printf '  %-12s %s\n' "$1" "$(printf '%s\n' "$output" | sed '/^[[:space:]]*$/d' | head -n 1)"
    else
        printf '  %-12s FAILED: %s\n' "$1" "$(printf '%s\n' "$output" | head -n 1)"
        FAILURES=$((FAILURES + 1))
    fi
}

check aws       'aws --version'
check bash      'bash --version'
check boto3     'python -c "import boto3; print(boto3.__version__)"'
check curl      'curl --version'
check git       'git --version'
check helm      'helm version --short'
check jq        'jq --version'
check kubectl   'kubectl version --client'
check psycopg   'python -c "import psycopg; print(psycopg.__version__, psycopg.pq.version())"'
check python    'python --version'
check yq        'yq --version'

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "All checks passed."
    exit 0
fi
echo "$FAILURES check(s) failed."
exit 1
