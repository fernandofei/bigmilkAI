#!/bin/bash
# Script: gerenciar_ia.sh
# Descrição: Painel de controle para o servidor de IA local
# Funcionalidades: Iniciar, Parar, Reiniciar, Status e Remover Tudo

# Configurações (as mesmas do script de instalação)
INSTALL_DIR="$HOME/ia_local"
OLLAMA_CONTAINER_NAME="ollama_server"
PORT_WEB=8000
SENHA_ADMIN=$(cat "$INSTALL_DIR/webapp/senha_admin.txt" 2>/dev/null || echo "admin123")

# Verificar se está sendo executado como root
if [ "$EUID" -eq 0 ]; then
    echo "ERRO: Não execute este script como root/sudo."
    exit 1
fi

# Função para autenticação
autenticar() {
    if [ ! -z "$SENHA_INFORMADA" ]; then
        # Se a senha foi passada por parâmetro
        if [ "$SENHA_INFORMADA" != "$SENHA_ADMIN" ]; then
            echo "Senha incorreta!"
            exit 1
        fi
    else
        # Pedir senha interativamente
        read -sp "Digite a senha de admin: " SENHA_DIGITADA
        echo
        if [ "$SENHA_DIGITADA" != "$SENHA_ADMIN" ]; then
            echo "Senha incorreta!"
            exit 1
        fi
    fi
}

# Função para remover tudo
remover_tudo() {
    autenticar
    
    echo "⚠️  ATENÇÃO: Isso removerá TODOS os dados e configurações!"
    read -p "Tem certeza que deseja continuar? (s/N): " CONFIRMACAO
    if [[ ! "$CONFIRMACAO" =~ [sS] ]]; then
        echo "Operação cancelada."
        exit 0
    fi

    echo "🛑 Parando serviços..."
    podman stop "$OLLAMA_CONTAINER_NAME" 2>/dev/null
    sudo systemctl stop ia-local-web 2>/dev/null

    echo "🧹 Removendo containers e serviços..."
    podman rm "$OLLAMA_CONTAINER_NAME" 2>/dev/null
    sudo systemctl disable ia-local-web 2>/dev/null
    sudo rm -f /etc/systemd/system/ia-local-web.service

    echo "🗑️  Removendo arquivos..."
    rm -rf "$INSTALL_DIR"
    rm -f "$HOME/instalar_ia_local.sh" "$HOME/gerenciar_ia.sh"

    echo "🔓 Liberando portas no firewall..."
    sudo firewall-cmd --remove-port=$PORT_WEB/tcp --permanent
    sudo firewall-cmd --reload

    echo "✅ Remoção completa! Todos os componentes foram desinstalados."
}

# Função para mostrar status
mostrar_status() {
    echo "=== Status dos Serviços ==="
    echo -n "• Ollama (container): "
    if podman ps -a --format "{{.Names}}" | grep -q "$OLLAMA_CONTAINER_NAME"; then
        echo "✅ Rodando"
    else
        echo "❌ Parado"
    fi

    echo -n "• IA Web (systemd): "
    if systemctl is-active --quiet ia-local-web; then
        echo "✅ Rodando"
    else
        echo "❌ Parado"
    fi

    echo -n "• Portas abertas: "
    sudo ss -tulnp | grep -E "$PORT_WEB|11434" || echo "Nenhuma porta ativa"

    echo -e "\n=== Acesso ==="
    echo "• Interface Web: http://$(hostname -I | awk '{print $1}'):$PORT_WEB"
    echo "• API Ollama: http://localhost:11434"
}

# Menu principal
case "$1" in
    start)
        echo "Iniciando serviços..."
        podman start "$OLLAMA_CONTAINER_NAME"
        sudo systemctl start ia-local-web
        mostrar_status
        ;;
    stop)
        autenticar
        echo "Parando serviços..."
        podman stop "$OLLAMA_CONTAINER_NAME"
        sudo systemctl stop ia-local-web
        mostrar_status
        ;;
    restart)
        autenticar
        echo "Reiniciando serviços..."
        podman restart "$OLLAMA_CONTAINER_NAME"
        sudo systemctl restart ia-local-web
        mostrar_status
        ;;
    status)
        mostrar_status
        ;;
    remove)
        remover_tudo
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|remove}"
        echo "Opções:"
        echo "  start     - Inicia todos os serviços"
        echo "  stop      - Para todos os serviços (requer senha)"
        echo "  restart   - Reinicia todos os serviços (requer senha)"
        echo "  status    - Mostra o status dos serviços"
        echo "  remove    - Remove completamente a instalação (requer senha)"
        echo
        echo "Dica: Para passar a senha automaticamente (útil para scripts):"
        echo "  SENHA='sua_senha' $0 comando"
        exit 1
        ;;
esac
