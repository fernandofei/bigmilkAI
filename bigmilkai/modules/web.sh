#!/bin/bash

source "$BASE_DIR/modules/utils.sh"

start_web_interface() {
    if [ ! -f "$BASE_DIR/web_interface.py" ]; then
        log_message "BigMilkAI environment not installed. Please select option 10 to install first."
        return
    fi
    log_message "Starting BigMilkAI web interface on http://localhost:5000..."
    cd "$BASE_DIR"
    nohup ./web_interface.py > "$LOG_FILE" 2>&1 &
    log_message "Web interface started! Access it at http://localhost:5000"
}
