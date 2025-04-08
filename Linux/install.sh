#!/bin/bash
# COMPLETE INSTALLER: Local AI + Dark Web Interface + Multi-User Access
# Single-file installer with admin/user roles and dark theme

# ==============================================
# MAIN CONFIGURATIONS
# ==============================================
INSTALL_DIR="$HOME/ia_local"
OLLAMA_CONTAINER="ollama_server"
PORT_WEB=8000
ADMIN_PWD="admin123"          # Admin password
USER_PWD="bigmilk123"         # Regular user password
LLM_MODEL="llama2"

# ==============================================
# HELPER FUNCTIONS
# ==============================================
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
fail() { red "$1"; exit 1; }

check_dependencies() {
    for cmd in podman python3 pip curl jq; do
        if ! command -v $cmd &>/dev/null; then
            fail "Error: '$cmd' not installed."
        fi
    done
}

# ==============================================
# 1. CORE INSTALLATION
# ==============================================
install_ia_local() {
    blue "\n🔧 INSTALLING LOCAL AI WITH DARK THEME..."

    # Create directory structure (including uploads)
    mkdir -p "$INSTALL_DIR"/{models,webapp/{templates,static/{js,css},logs},uploads}
    chmod 755 "$INSTALL_DIR/uploads"  # Ensure uploads directory has correct permissions

    # 1.1 Install Ollama via Podman (with proper error handling)
    mkdir -p "$INSTALL_DIR/models"  # Ensure directory exists

    if ! podman ps -a --format "{{.Names}}" | grep -q "$OLLAMA_CONTAINER"; then
        green "\n🐳 Installing Ollama (Podman container)..."
        if ! podman run -d \
            --name "$OLLAMA_CONTAINER" \
            -p 11434:11434 \
            -v "$INSTALL_DIR/models:/root/.ollama" \
            docker.io/ollama/ollama:latest; then
            fail "Failed to create Ollama container"
        fi

        green "⏳ Downloading $LLM_MODEL model..."
        sleep 10  # Wait for container initialization
        if ! podman exec "$OLLAMA_CONTAINER" ollama pull "$LLM_MODEL"; then
            fail "Failed to download model"
        fi
    else
        green "✔ Ollama already installed."
    fi

    # 1.2 Install Python dependencies
    green "\n🐍 Installing Python dependencies..."
    pip install --user fastapi uvicorn httpx PyPDF2 python-jose passlib bcrypt sqlalchemy

    # 1.3 Create application files with dark theme and multi-access
    green "\n💻 Creating web application..."

    # main.py (with user management)
    cat > "$INSTALL_DIR/webapp/main.py" <<'EOL'
import os, io, json, logging
from datetime import datetime
from fastapi import FastAPI, UploadFile, File, Request, Form, Depends, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.security import HTTPBasic, HTTPBasicCredentials
import httpx, PyPDF2
from typing import Optional, Dict
from passlib.context import CryptContext
from pydantic import BaseModel

# Configuration
app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")
security = HTTPBasic()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# User database (will be loaded from file)
USERS_FILE = "users.json"
USERS: Dict[str, dict] = {}

# User model
class UserModel(BaseModel):
    username: str
    password: str
    role: str

# Load users from file
def load_users():
    global USERS
    try:
        if os.path.exists(USERS_FILE):
            with open(USERS_FILE, "r") as f:
                USERS = json.load(f)
        else:
            # Default users
            USERS = {
                "admin": {
                    "password": pwd_context.hash("admin123"),
                    "role": "admin"
                },
                "bigmilk": {
                    "password": pwd_context.hash("bigmilk123"),
                    "role": "user"
                }
            }
            save_users()
    except Exception as e:
        logging.error(f"Error loading users: {str(e)}")
        USERS = {}

# Save users to file
def save_users():
    try:
        with open(USERS_FILE, "w") as f:
            json.dump(USERS, f)
    except Exception as e:
        logging.error(f"Error saving users: {str(e)}")

# Initialize users
load_users()

# Logging setup
LOG_DIR = os.path.join(os.path.dirname(__file__), "logs")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'execution.log')),
        logging.StreamHandler()
    ]
)

def verify_user(credentials: HTTPBasicCredentials = Depends(security)):
    user = USERS.get(credentials.username)
    if not user or not pwd_context.verify(credentials.password, user["password"]):
        raise HTTPException(
            status_code=401,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return user

def log_chat(username: str, prompt: str, response: str):
    with open(os.path.join(LOG_DIR, 'chat_history.log'), 'a') as f:
        f.write(json.dumps({
            "timestamp": datetime.now().isoformat(),
            "username": username,
            "prompt": prompt,
            "response": response
        }) + '\n')

# Routes
@app.get("/", response_class=HTMLResponse)
async def home(request: Request, user: dict = Depends(verify_user)):
    return templates.TemplateResponse("index.html", {
        "request": request,
        "user_role": user["role"],
        "username": credentials.username if "credentials" in locals() else user["role"]
    })

@app.post("/upload")
async def upload_pdf(file: UploadFile = File(...), user: dict = Depends(verify_user)):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admins can upload files")

    try:
        # Ensure uploads directory exists
        os.makedirs("uploads", exist_ok=True)
        
        contents = await file.read()
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(contents))
        text = "\n".join([page.extract_text() for page in pdf_reader.pages])

        filename = f"{file.filename}.txt"
        with open(os.path.join("uploads", filename), "w") as f:
            f.write(text)

        return {"filename": filename, "pages": len(pdf_reader.pages)}
    except Exception as e:
        logging.error(f"Upload error: {str(e)}")
        return {"error": str(e)}

@app.post("/chat")
async def chat_with_ai(
    prompt: str = Form(...),
    user: dict = Depends(verify_user)
):
    try:
        start_time = datetime.now()
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={"model": "llama2", "prompt": prompt, "stream": False},
                timeout=60.0
            )
            response.raise_for_status()
            result = response.json()

            log_chat(user["role"], prompt, result['response'])
            logging.info(f"Chat completed in {(datetime.now() - start_time).total_seconds():.2f}s - User: {user['role']} - Prompt: {prompt[:50]}...")

            return result
    except Exception as e:
        logging.error(f"Chat error: {str(e)}")
        return {"error": str(e)}

# User management routes
@app.get("/users", response_class=HTMLResponse)
async def manage_users(request: Request, user: dict = Depends(verify_user)):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admins can manage users")
    return templates.TemplateResponse("users.html", {
        "request": request,
        "users": USERS
    })

@app.post("/users/create")
async def create_user(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    role: str = Form(...),
    user: dict = Depends(verify_user)
):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admins can create users")
    
    if username in USERS:
        raise HTTPException(status_code=400, detail="User already exists")
    
    USERS[username] = {
        "password": pwd_context.hash(password),
        "role": role
    }
    save_users()
    
    return RedirectResponse(url="/users", status_code=303)

@app.post("/users/update")
async def update_user(
    request: Request,
    username: str = Form(...),
    new_password: str = Form(None),
    new_role: str = Form(None),
    user: dict = Depends(verify_user)
):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admins can update users")
    
    if username not in USERS:
        raise HTTPException(status_code=404, detail="User not found")
    
    if new_password:
        USERS[username]["password"] = pwd_context.hash(new_password)
    if new_role:
        USERS[username]["role"] = new_role
    
    save_users()
    return RedirectResponse(url="/users", status_code=303)

@app.post("/users/delete")
async def delete_user(
    request: Request,
    username: str = Form(...),
    user: dict = Depends(verify_user)
):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admins can delete users")
    
    if username not in USERS:
        raise HTTPException(status_code=404, detail="User not found")
    
    if username == "admin":
        raise HTTPException(status_code=400, detail="Cannot delete admin user")
    
    del USERS[username]
    save_users()
    return RedirectResponse(url="/users", status_code=303)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOL

    # index.html (dark theme with user management link)
    cat > "$INSTALL_DIR/webapp/templates/index.html" <<'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BigMilk AI</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        :root {
            --bg-dark: #1a1a1a;
            --bg-darker: #121212;
            --primary: #6e48aa;
            --text: #e0e0e0;
            --text-muted: #a0a0a0;
        }
        body {
            background-color: var(--bg-dark);
            color: var(--text);
            min-height: 100vh;
        }
        .navbar {
            background-color: var(--bg-darker) !important;
            border-bottom: 1px solid #333;
        }
        .card {
            background-color: var(--bg-darker);
            border: 1px solid #333;
            color: var(--text);
        }
        .form-control, .form-control:focus {
            background-color: #2a2a2a;
            color: var(--text);
            border-color: #444;
        }
        .user-message {
            background: var(--primary);
            color: white;
            border-radius: 15px;
            padding: 10px 15px;
            margin: 8px;
            max-width: 70%;
            float: right;
            clear: both;
            border-bottom-right-radius: 5px;
        }
        .ai-message {
            background: #2a2a2a;
            color: var(--text);
            border-radius: 15px;
            padding: 10px 15px;
            margin: 8px;
            max-width: 70%;
            float: left;
            clear: both;
            border-bottom-left-radius: 5px;
            border: 1px solid #333;
        }
        #chatContainer {
            height: 60vh;
            overflow-y: auto;
            padding: 10px;
            background-color: var(--bg-dark);
            border-radius: 10px;
            margin-bottom: 15px;
        }
        .hidden {
            display: none !important;
        }
        .admin-link {
            color: var(--primary) !important;
            text-decoration: none;
            margin-left: 15px;
        }
    </style>
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark mb-4">
        <div class="container">
            <a class="navbar-brand" href="#">BigMilk AI</a>
            <span class="navbar-text ms-auto">
                Logged in as: <strong>{{ username }}</strong>
                {% if user_role == 'admin' %}
                <a href="/users" class="admin-link">Manage Users</a>
                {% endif %}
            </span>
        </div>
    </nav>

    <div class="container">
        <div class="row">
            <!-- Upload Section (admin only) -->
            <div class="col-md-6" id="uploadSection" :class="{'hidden': user_role !== 'admin'}">
                <div class="card mb-4">
                    <div class="card-header" style="background-color: var(--primary);">
                        <h5>Upload PDF</h5>
                    </div>
                    <div class="card-body">
                        <form id="uploadForm" enctype="multipart/form-data">
                            <input class="form-control mb-3" type="file" name="file" accept=".pdf" required>
                            <button type="submit" class="btn" style="background-color: var(--primary); color: white;">Upload PDF</button>
                        </form>
                        <div id="uploadStatus" class="mt-3"></div>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header" style="background-color: var(--primary);">
                        <h5>Uploaded Documents</h5>
                    </div>
                    <div class="card-body">
                        <ul id="documentsList" class="list-group" style="background-color: var(--bg-dark);">
                            <!-- Documents will appear here -->
                        </ul>
                    </div>
                </div>
            </div>

            <!-- Chat Section (all users) -->
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header" style="background-color: var(--primary);">
                        <h5>AI Chat</h5>
                    </div>
                    <div class="card-body">
                        <div id="chatContainer"></div>
                        <form id="chatForm">
                            <textarea class="form-control mb-3" id="promptInput" rows="3"
                                      placeholder="Type your question..." required></textarea>
                            <button type="submit" class="btn" style="background-color: var(--primary); color: white;">Send</button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Show/hide sections based on user role
        document.addEventListener('DOMContentLoaded', () => {
            const userRole = "{{ user_role }}";
            if(userRole !== 'admin') {
                document.getElementById('uploadSection').classList.add('hidden');
            }
        });
    </script>
    <script src="/static/js/app.js"></script>
</body>
</html>
EOL

    # users.html (user management interface)
    cat > "$INSTALL_DIR/webapp/templates/users.html" <<'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>User Management</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        :root {
            --bg-dark: #1a1a1a;
            --bg-darker: #121212;
            --primary: #6e48aa;
            --text: #e0e0e0;
            --text-muted: #a0a0a0;
        }
        body {
            background-color: var(--bg-dark);
            color: var(--text);
        }
        .navbar {
            background-color: var(--bg-darker) !important;
            border-bottom: 1px solid #333;
        }
        .card {
            background-color: var(--bg-darker);
            border: 1px solid #333;
            color: var(--text);
        }
        .form-control, .form-control:focus {
            background-color: #2a2a2a;
            color: var(--text);
            border-color: #444;
        }
        .table-dark {
            --bs-table-bg: var(--bg-darker);
            --bs-table-striped-bg: #2a2a2a;
            --bs-table-hover-bg: #333;
        }
    </style>
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark mb-4">
        <div class="container">
            <a class="navbar-brand" href="/">BigMilk AI</a>
            <span class="navbar-text ms-auto">
                <a href="/" class="btn btn-sm btn-outline-primary">Back to Chat</a>
            </span>
        </div>
    </nav>

    <div class="container">
        <div class="row">
            <div class="col-md-12">
                <div class="card mb-4">
                    <div class="card-header" style="background-color: var(--primary);">
                        <h5>Create New User</h5>
                    </div>
                    <div class="card-body">
                        <form action="/users/create" method="post">
                            <div class="row">
                                <div class="col-md-3">
                                    <input type="text" class="form-control mb-2" name="username" placeholder="Username" required>
                                </div>
                                <div class="col-md-3">
                                    <input type="password" class="form-control mb-2" name="password" placeholder="Password" required>
                                </div>
                                <div class="col-md-3">
                                    <select class="form-select mb-2" name="role" required>
                                        <option value="admin">Admin</option>
                                        <option value="user" selected>User</option>
                                    </select>
                                </div>
                                <div class="col-md-3">
                                    <button type="submit" class="btn btn-primary w-100">Create User</button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header" style="background-color: var(--primary);">
                        <h5>Manage Users</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-dark table-hover">
                                <thead>
                                    <tr>
                                        <th>Username</th>
                                        <th>Role</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {% for username, user in users.items() %}
                                    <tr>
                                        <td>{{ username }}</td>
                                        <td>{{ user.role }}</td>
                                        <td>
                                            <form action="/users/update" method="post" style="display: inline;">
                                                <input type="hidden" name="username" value="{{ username }}">
                                                <input type="password" class="form-control form-control-sm d-inline-block w-auto" name="new_password" placeholder="New password">
                                                <select class="form-select form-select-sm d-inline-block w-auto" name="new_role">
                                                    <option value="">No change</option>
                                                    <option value="admin">Admin</option>
                                                    <option value="user">User</option>
                                                </select>
                                                <button type="submit" class="btn btn-sm btn-outline-primary">Update</button>
                                            </form>
                                            {% if username != 'admin' %}
                                            <form action="/users/delete" method="post" style="display: inline;">
                                                <input type="hidden" name="username" value="{{ username }}">
                                                <button type="submit" class="btn btn-sm btn-outline-danger">Delete</button>
                                            </form>
                                            {% endif %}
                                        </td>
                                    </tr>
                                    {% endfor %}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOL

    # app.js (updated for user management)
    cat > "$INSTALL_DIR/webapp/static/js/app.js" <<'EOL'
document.addEventListener('DOMContentLoaded', () => {
    const chatForm = document.getElementById('chatForm');
    const uploadForm = document.getElementById('uploadForm');
    const chatContainer = document.getElementById('chatContainer');

    // Chat configuration
    chatForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const prompt = document.getElementById('promptInput').value;
        if (!prompt.trim()) return;

        addMessage(prompt, 'user');
        document.getElementById('promptInput').value = '';

        try {
            const response = await fetch('/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({ prompt })
            });
            const result = await response.json();
            addMessage(result.response || result.error, result.error ? 'error' : 'ai');
        } catch (error) {
            addMessage(`Error: ${error.message}`, 'error');
        }
    });

    // Upload configuration (only shown for admin)
    if(uploadForm) {
        uploadForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(uploadForm);

            try {
                const response = await fetch('/upload', {
                    method: 'POST',
                    body: formData
                });
                const result = await response.json();
                showAlert(result.error || `PDF ${result.filename} uploaded (${result.pages} pages)`);
            } catch (error) {
                showAlert(`Error: ${error.message}`);
            }
        });
    }

    function addMessage(text, type) {
        const div = document.createElement('div');
        div.className = type === 'user' ? 'user-message' :
                        type === 'error' ? 'alert alert-danger' : 'ai-message';
        div.textContent = text;
        chatContainer.appendChild(div);
        chatContainer.scrollTop = chatContainer.scrollHeight;
    }

    function showAlert(message) {
        const alertDiv = document.createElement('div');
        alertDiv.className = 'alert alert-info';
        alertDiv.textContent = message;
        document.getElementById('uploadStatus').appendChild(alertDiv);
        setTimeout(() => alertDiv.remove(), 3000);
    }
});
EOL

    # 1.4 Update passwords in main.py
    sed -i "s|pwd_context.hash(\"admin123\")|pwd_context.hash(\"$ADMIN_PWD\")|g" "$INSTALL_DIR/webapp/main.py"
    sed -i "s|pwd_context.hash(\"bigmilk123\")|pwd_context.hash(\"$USER_PWD\")|g" "$INSTALL_DIR/webapp/main.py"

    # 1.5 Create systemd service
    green "\n🛠️ Configuring systemd service..."
    sudo tee /etc/systemd/system/ia-local-web.service > /dev/null <<EOL
[Unit]
Description=BigMilk AI Web Interface
After=network.target

[Service]
User=$USER
WorkingDirectory=$INSTALL_DIR/webapp
ExecStart=$(which uvicorn) main:app --host 0.0.0.0 --port $PORT_WEB
Restart=always
RestartSec=5
Environment="PATH=/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOL

    # 1.6 Configure firewall
    green "\n🔥 Configuring firewall..."
    sudo firewall-cmd --add-port=$PORT_WEB/tcp --permanent
    sudo firewall-cmd --reload

    # 1.7 Start services
    green "\n🚀 Starting services..."
    podman start "$OLLAMA_CONTAINER"
    sudo systemctl daemon-reload
    sudo systemctl enable --now ia-local-web

    # 1.8 Save credentials
    echo "admin:$ADMIN_PWD" > "$INSTALL_DIR/webapp/credentials.txt"
    echo "bigmilk:$USER_PWD" >> "$INSTALL_DIR/webapp/credentials.txt"
    chmod 600 "$INSTALL_DIR/webapp/credentials.txt"
}

# ==============================================
# 2. MANAGEMENT SCRIPT
# ==============================================
create_management_script() {
    green "\n📜 Creating management script..."
    cat > "$INSTALL_DIR/manage.sh" <<'EOL'
#!/bin/bash
# Script: manage.sh
# Description: Control panel for Local AI

INSTALL_DIR=$(dirname "$(readlink -f "$0")")/..
ADMIN_PWD=$(cat "$INSTALL_DIR/webapp/credentials.txt" 2>/dev/null | grep "^admin:" | cut -d: -f2)

check_password() {
    if [ -z "$ADMIN_PWD" ]; then
        echo "ERROR: Admin password not configured."
        exit 1
    fi

    if [ "$1" != "$ADMIN_PWD" ]; then
        echo "Incorrect password!"
        exit 1
    fi
}

case "$1" in
    start)
        podman start ollama_server
        sudo systemctl start ia-local-web
        echo "Services started."
        ;;
    stop)
        read -sp "Admin password: " PASSWORD
        check_password "$PASSWORD"
        podman stop ollama_server
        sudo systemctl stop ia-local-web
        echo "Services stopped."
        ;;
    restart)
        read -sp "Admin password: " PASSWORD
        check_password "$PASSWORD"
        podman restart ollama_server
        sudo systemctl restart ia-local-web
        echo "Services restarted."
        ;;
    status)
        echo "=== Service Status ==="
        podman ps -f name=ollama_server
        sudo systemctl status ia-local-web --no-pager -n 5
        ;;
    logs)
        tail -n 20 "$INSTALL_DIR/webapp/logs/execution.log"
        ;;
    remove)
        read -sp "Admin password: " PASSWORD
        check_password "$PASSWORD"
        echo -e "\n⚠️  COMPLETE UNINSTALLATION..."
        podman stop ollama_server && podman rm ollama_server
        sudo systemctl stop ia-local-web && sudo systemctl disable ia-local-web
        sudo rm -f /etc/systemd/system/ia-local-web.service
        rm -rf "$INSTALL_DIR"
        echo "✅ Removal complete."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|remove}"
        exit 1
        ;;
esac
EOL

    chmod +x "$INSTALL_DIR/manage.sh"
    sudo ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/manage-ai
}

# ==============================================
# 3. LOGS SCRIPT
# ==============================================
create_logs_script() {
    green "\n📝 Creating log viewer script..."
    cat > "$INSTALL_DIR/view_logs.sh" <<'EOL'
#!/bin/bash
# Script: view_logs.sh
# Description: View Local AI logs

LOG_DIR="$(dirname "$(readlink -f "$0")")/webapp/logs"

case "$1" in
    chat)
        echo "=== Chat History ==="
        jq -r '"\(.timestamp) | User: \(.username) | Q: \(.prompt[:50])... | A: \(.response[:50])..."' "$LOG_DIR/chat_history.log" | tail -n 20
        ;;
    server)
        echo "=== Server Logs ==="
        tail -n 20 "$LOG_DIR/execution.log"
        ;;
    all)
        echo "=== All Logs ==="
        tail -n 15 "$LOG_DIR"/*.log
        ;;
    *)
        echo "Usage: $0 {chat|server|all}"
        exit 1
        ;;
esac
EOL

    chmod +x "$INSTALL_DIR/view_logs.sh"
    sudo ln -sf "$INSTALL_DIR/view_logs.sh" /usr/local/bin/ai-logs
}

# ==============================================
# MAIN EXECUTION
# ==============================================
main() {
    clear
    echo "=============================================="
    echo " BIGMILK AI - COMPLETE INSTALLER"
    echo "=============================================="
    echo "• Install Dir: $INSTALL_DIR"
    echo "• Container: $OLLAMA_CONTAINER"
    echo "• Web Port: $PORT_WEB"
    echo "• LLM Model: $LLM_MODEL"
    echo "• Credentials:"
    echo "  - admin: $ADMIN_PWD"
    echo "  - bigmilk: $USER_PWD"
    echo "=============================================="

    check_dependencies
    install_ia_local
    create_management_script
    create_logs_script

    green "\n✅✅✅ INSTALLATION COMPLETE! ✅✅✅"
    echo "=============================================="
    echo " ACCESS:"
    echo "• Web Interface: http://$(hostname -I | awk '{print $1}'):$PORT_WEB"
    echo "• API Ollama: http://localhost:11434"
    echo
    echo " CREDENTIALS:"
    echo "• Admin (full access): username 'admin'"
    echo "• User (chat only): username 'bigmilk'"
    echo
    echo " NEW FEATURES:"
    echo "• Fixed uploads directory issue"
    echo "• Added complete user management (create/edit/delete)"
    echo "• Admin can now change passwords and roles"
    echo
    echo " MANAGEMENT:"
    echo "• sudo systemctl [start|stop|restart|status] ia-local-web"
    echo "• podman [start|stop|restart] $OLLAMA_CONTAINER"
    echo "• manage-ai [start|stop|restart|status|logs|remove]"
    echo "• ai-logs [chat|server|all]"
    echo "=============================================="
}

main
