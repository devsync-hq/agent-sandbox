#!/usr/bin/env bash
set -euo pipefail

git subtree push --prefix=services/agent-sandbox agent-sandbox-public main
