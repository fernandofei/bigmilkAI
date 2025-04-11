#!/bin/bash

source "$BASE_DIR/modules/utils.sh"

start_services() {
    if ! command -v ollama >/dev/null 2>&1 || ! podman ps -a | grep -q "open-webui"; then
        log_message "BigMilkAI environment not fully installed. Please select option 10 to install first."
        return
    fi
    log_message "Starting Ollama for BigMilkAI..."
    if systemctl --user status ollama >/dev/null 2>&1; then
        systemctl --user start ollama || {
            log_message "Failed to start Ollama service. Attempting to enable it..."
            systemctl --user enable --now ollama || log_message "Failed to enable Ollama service."
        }
    else
        log_message "Ollama not configured as a service. Starting manually..."
        ollama serve &
        sleep 2
    fi
    log_message "Starting Open WebUI..."
    podman start open-webui || {
        log_message "Open WebUI not running. Recreating container..."
        podman run -d -p 8080:8080 \
          --network=host \
          -v open-webui:/app/backend/data \
          -e "OLLAMA_API_BASE_URL=http://127.0.0.1:11434" \
          -e "OLLAMA_HOST=http://127.0.0.1:11434" \
          -e "DEFAULT_OLLAMA_HOST=http://127.0.0.1:11434" \
          --name open-webui \
          --replace \
          ghcr.io/open-webui/open-webui:main 2>> "$LOG_FILE"
    }
    log_message "BigMilkAI services started!"
}

stop_services() {
    log_message "Stopping Ollama..."
    if systemctl --user status ollama >/dev/null 2>&1; then
        systemctl --user stop ollama || log_message "Failed to stop Ollama service"
    else
        pkill -f "ollama serve" >/dev/null 2>&1 && log_message "Ollama stopped" || log_message "Ollama not running"
    fi
    log_message "Stopping Open WebUI..."
    podman stop open-webui >/dev/null 2>> "$LOG_FILE" && log_message "Open WebUI stopped" || log_message "Open WebUI not running"
    log_message "BigMilkAI services stopped!"
}

restart_services() {
    stop_services
    start_services
    log_message "BigMilkAI services restarted!"
}

check_status() {
    log_message "Checking Ollama status..."
    echo "Checking Ollama status..."
    if systemctl --user status ollama >/dev/null 2>&1; then
        systemctl --user status ollama --no-pager
    else
        pgrep -f "ollama serve" >/dev/null && echo "Ollama is running manually" || echo "Ollama is not running"
    fi
    log_message "Checking Open WebUI status..."
    echo "Checking Open WebUI status..."
    podman ps -a | grep open-webui || echo "Open WebUI is not running"
}

view_logs() {
    log_message "Viewing logs..."
    echo "=== BigMilkAI Script Logs ==="
    if [ -f "$LOG_FILE" ]; then
        cat "$LOG_FILE"
    else
        echo "No script logs found at $LOG_FILE."
    fi
    echo ""
    echo "=== Ollama Logs (if running as service) ==="
    if systemctl --user status ollama >/dev/null 2>&1; then
        journalctl --user-unit ollama --no-pager
    else
        echo "Ollama not running as a service; no logs available."
    fi
    echo ""
    echo "=== Open WebUI Logs ==="
    podman logs open-webui || echo "No logs available for Open WebUI."
}

toggle_boot() {
    log_message "Enable or disable BigMilkAI services on boot? (1 = Enable, 2 = Disable)"
    echo "Enable or disable BigMilkAI services on boot? (1 = Enable, 2 = Disable)"
    read -p "Choice: " boot_choice
    if [ "$boot_choice" = "1" ]; then
        systemctl --user enable ollama >/dev/null 2>&1 || log_message "Ollama service not installed yet"
        log_message "BigMilkAI services enabled on boot."
    elif [ "$boot_choice" = "2" ]; then
        systemctl --user disable ollama >/dev/null 2>&1 || log_message "Ollama service not installed yet"
        log_message "BigMilkAI services disabled on boot."
    else
        log_message "Invalid choice."
    fi
}
