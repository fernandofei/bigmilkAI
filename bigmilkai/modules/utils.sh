#!/bin/bash

# Log file
LOG_FILE="$BASE_DIR/big_milk_ai.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
