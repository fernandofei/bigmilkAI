#!/bin/bash

source "$BASE_DIR/modules/utils.sh"

show_network_details() {
    log_message "Showing network details..."
    echo "=== BigMilkAI Network Details ==="
    echo "Hostname: $(hostname)"
    echo "Local IPs:"
    ip addr show | grep "inet " | awk '{print "  " $2}' | grep -v "127.0.0.1"
    echo "Loopback IP: 127.0.0.1"
    echo ""
    echo "Service Details:"
    echo "  Ollama:"
    echo "    - IP: 127.0.0.1"
    echo "    - Port: 11434"
    echo "    - Status: $(if systemctl --user status ollama >/dev/null 2>&1; then echo "Running (systemd)"; elif pgrep -f 'ollama serve' >/dev/null; then echo "Running (manual)"; else echo "Not running"; fi)"
    echo "  Open WebUI:"
    echo "    - IP: localhost (or any local IP above)"
    echo "    - Port: 8080"
    echo "    - Status: $(if podman ps | grep -q 'open-webui'; then echo "Running"; else echo "Not running"; fi)"
    echo "    - URL: http://localhost:8080"
    echo "  Web Interface:"
    echo "    - IP: localhost (or any local IP above)"
    echo "    - Port: 5000"
    echo "    - Status: $(if pgrep -f 'web_interface.py' >/dev/null; then echo "Running"; else echo "Not running"; fi)"
    echo "    - URL: http://localhost:5000"
    echo "================================="
}
