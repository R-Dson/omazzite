#!/bin/bash

# Source omadora environment variables
if [ -f "$HOME/.config/uwsm/env" ]; then
  source "$HOME/.config/uwsm/env"
fi
export PATH="$HOME/.local/share/omadora/bin:$PATH"