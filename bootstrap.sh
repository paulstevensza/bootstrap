#!/usr/bin/env bash

###
# Run the appropriate setup dependent on the system.
# @author Paul Stevens
###

if [[ uname == "Darwin" ]]; then
  source bootstrap_mac.sh
fi;
