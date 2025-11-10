#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$SCRIPT_DIR/../MacOS/Pearcleaner" ask-password --message "Homebrew is requesting your password to perform a privileged action"
