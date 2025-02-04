from flask import (
    Flask,
    render_template,
    request,
    redirect,
    url_for,
    session,
    jsonify,
    send_file
)
import sqlite3
import csv
import io
import re
import random
from datetime import datetime, timedelta
import requests  # Only used for non-FCM calls if needed

# 1) Import and enable CORS
from flask_cors import CORS

# 2) Import Twilio client
from twilio.rest import Client

# 3) Import Firebase Admin SDK modules
import firebase_admin
from firebase_admin import credentials, messaging

app = Flask(__name__)
app.secret_key = "my-very-strong-secret-key"  # Change this to something secure

# Enable CORS for all routes
CORS(app)

LIVE_BASE_URL = "https://molentracker.ermine.at"
DATABASE = 'database.db'

######################### TWILIO CONFIGURATION #########################
TWILIO_ACCOUNT_SID = "ACc21e0ab649ebe0280c1cab26ebdb92be"
TWILIO_AUTH_TOKEN = "4799cd1a4a179d21f1fc1083aab66736"
TWILIO_FROM_NUMBER = "+14243294447"  # Your Twilio phone number
#########################################################################

# Legacy phone->username mapping (no longer used for OTP registration)
PHONE_TO_USERNAME = {
    "+436703596614": "otter",
    "+4369910503659": "weasel"
}

# Dictionary to store OTP requests (transient)
pending_otps = {}

# ----- Firebase Admin Initialization -----
try:
    cred = credentials.Certificate("service-account.json")
    firebase_admin.initialize_app(cred)
    log_msg = "Firebase Admin initialized successfully."
except Exception as e:
    log_msg = f"Error initializing Firebase Admin: {e}"
print(f"[DEBUG] {log_msg}")

# ---------------- Helper Functions ----------------

def normalize_phone(phone: str) -> str:
    p = re.sub(r"[^0-9+]", "", phone)
    if not p.startswith('+'):
        p = '+' + p
    return p

def generate_otp_code() -> str:
    return f"{random.randint(0,999999):06d}"

def send_otp_sms(phone: str, code: str):
    body_text = f"Your OTP code is: {code}"
    try:
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        message = client.messages.create(
            body=body_text,
            from_=TWILIO_FROM_NUMBER,
            to=phone
        )
        log(f"[send_otp_sms] Sent OTP {code} to phone={phone}, SID={message.sid}")
    except Exception as e:
        log(f"[send_otp_sms] Error sending OTP via Twilio: {e}")

def get_db_connection():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def log(msg):
    print(f"[DEBUG] {msg}")

@app.template_filter("human_date")
def human_date(value):
    if not value:
        return ""
    dt = datetime.fromisoformat(value)
    return dt.strftime("%d.%m.%Y, %H:%M")

@app.template_filter("time_taken")
def time_taken(created_str, completed_str):
    if not created_str or not completed_str:
        return ""
    dt_created = datetime.fromisoformat(created_str)
    dt_completed = datetime.fromisoformat(completed_str)
    diff = dt_completed - dt_created
    days = diff.days
    secs = diff.seconds
    hours = secs // 3600
    minutes = (secs % 3600) // 60
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes:
        parts.append(f"{minutes}m")
    return " ".join(parts) if parts else "0m"

@app.template_filter("to_datetime")
def to_datetime_filter(value):
    if not value:
        return None
    return datetime.fromisoformat(value)

# ---------------- Permission and SOP Helper Functions ----------------

def get_user_permissions(username: str) -> set:
    """
    Load all groups the user belongs to and then aggregate permissions.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT group_id FROM user_groups WHERE username=?", (username,))
    group_rows = cursor.fetchall()
    groups = [row["group_id"] for row in group_rows]
    permissions = set()
    if groups:
        placeholder = ','.join('?' * len(groups))
        cursor.execute(f"""
            SELECT p.name FROM permissions p 
            JOIN group_permissions gp ON p.id = gp.permission_id 
            WHERE gp.group_id IN ({placeholder})
        """, groups)
        perm_rows = cursor.fetchall()
        for row in perm_rows:
            permissions.add(row["name"])
    conn.close()
    log(f"[get_user_permissions] User '{username}' has permissions: {permissions}")
    return permissions

def requires_permission(permission_name):
    """
    Decorator to require a given permission.
    """
    def decorator(f):
        def wrapper(*args, **kwargs):
            username = session.get('username')
            if not username:
                return jsonify({"error": "Not authenticated"}), 401
            user_perms = get_user_permissions(username)
            if permission_name not in user_perms:
                log(f"[requires_permission] User '{username}' missing permission '{permission_name}'")
                return jsonify({"error": "Permission denied", "required": permission_name}), 403
            return f(*args, **kwargs)
        wrapper.__name__ = f.__name__
        return wrapper
    return decorator

def requires_sop_agreement(sop_title):
    """
    Decorator to ensure the current user has agreed to the latest version of the given SOP.
    """
    def decorator(f):
        def wrapper(*args, **kwargs):
            username = session.get('username')
            if not username:
                return jsonify({"error": "Not authenticated"}), 401
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM sops WHERE title=?", (sop_title,))
            sop = cursor.fetchone()
            if not sop:
                conn.close()
                return jsonify({"error": f"SOP '{sop_title}' not found"}), 404
            current_version = sop["version"]
            cursor.execute("""
                SELECT * FROM sop_agreements 
                WHERE username=? AND sop_id=? AND sop_version=?
            """, (username, sop["id"], current_version))
            agreement = cursor.fetchone()
            conn.close()
            if not agreement:
                log(f"[requires_sop_agreement] User '{username}' has not agreed to SOP '{sop_title}' version {current_version}")
                return jsonify({
                    "error": "SOP agreement required", 
                    "sop_title": sop_title, 
                    "version": current_version
                }), 403
            return f(*args, **kwargs)
        wrapper.__name__ = f.__name__
        return wrapper
    return decorator

# ---------------- Database Initialization ----------------

def init_db():
    log("Initializing database...")
    conn = get_db_connection()
    cursor = conn.cursor()
    # Create tasks table with recurring fields and group association
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            assigned_to TEXT,
            creation_date TEXT,
            due_date TEXT,
            completed BOOLEAN DEFAULT 0,
            completed_by TEXT,
            completed_on TEXT,
            recurring BOOLEAN DEFAULT 0,
            frequency_hours INTEGER,
            always_assigned BOOLEAN DEFAULT 1,
            group_id TEXT
        )
    ''')
    # Create device_tokens table for push notifications
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS device_tokens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            token TEXT
        )
    ''')
    # Create projects table with group association
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_by TEXT,
            creation_date TEXT,
            group_id TEXT
        )
    ''')
    # Create project_todos table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS project_todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            due_date TEXT,
            is_task BOOLEAN DEFAULT 0,
            assigned_to TEXT,
            points INTEGER DEFAULT 0,
            creation_date TEXT,
            completed BOOLEAN DEFAULT 0,
            completed_by TEXT,
            completed_on TEXT,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        )
    ''')
    # Create users table for registration
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT UNIQUE NOT NULL,
            username TEXT UNIQUE NOT NULL
        )
    ''')
    # Create groups table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            creator TEXT
        )
    ''')
    # Create permissions table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT
        )
    ''')
    # Create group_permissions mapping table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS group_permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            permission_id INTEGER NOT NULL,
            FOREIGN KEY(group_id) REFERENCES groups(id),
            FOREIGN KEY(permission_id) REFERENCES permissions(id)
        )
    ''')
    # Create user_groups mapping table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            group_id INTEGER NOT NULL,
            role TEXT DEFAULT 'user',
            FOREIGN KEY(group_id) REFERENCES groups(id)
        )
    ''')
    # Create sops table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT,
            version TEXT NOT NULL,
            published_date TEXT,
            effective_date TEXT,
            group_id TEXT
        )
    ''')
    # Create sop_agreements table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sop_agreements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sop_id INTEGER NOT NULL,
            username TEXT NOT NULL,
            agreed_at TEXT,
            sop_version TEXT NOT NULL,
            FOREIGN KEY(sop_id) REFERENCES sops(id)
        )
    ''')
    # Insert default tasks if none exist
    cursor.execute('SELECT COUNT(*) as count FROM tasks')
    count_tasks = cursor.fetchone()['count']
    if count_tasks == 0:
        log("No tasks found; inserting default tasks: Wäsche, Küche, kochen.")
        now_str = datetime.utcnow().isoformat()
        cursor.execute("INSERT INTO tasks (title, creation_date, group_id) VALUES (?, ?, ?)", ("Wäsche", now_str, "default"))
        cursor.execute("INSERT INTO tasks (title, creation_date, group_id) VALUES (?, ?, ?)", ("Küche", now_str, "default"))
        cursor.execute("INSERT INTO tasks (title, creation_date, group_id) VALUES (?, ?, ?)", ("kochen", now_str, "default"))
        conn.commit()
    conn.close()
    log("Database init complete.")

def get_registered_users():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT username FROM users")
    rows = cursor.fetchall()
    conn.close()
    users = [row["username"] for row in rows]
    log(f"[get_registered_users] Found {len(users)} registered user(s).")
    return users

# ---------------- Group & Permission Management Endpoints ----------------

@app.route('/api/permissions', methods=['GET'])
@requires_permission("manage_permissions")
def api_get_permissions():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM permissions")
    perms = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jsonify(perms), 200

@app.route('/api/permissions', methods=['POST'])
@requires_permission("manage_permissions")
def api_create_permission():
    data = request.get_json() or {}
    name = data.get("name", "").strip()
    description = data.get("description", "")
    if not name:
        return jsonify({"error": "Permission name is required"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO permissions (name, description) VALUES (?, ?)", (name, description))
    conn.commit()
    new_id = cursor.lastrowid
    cursor.execute("SELECT * FROM permissions WHERE id=?", (new_id,))
    perm = dict(cursor.fetchone())
    conn.close()
    return jsonify(perm), 201

@app.route('/api/groups', methods=['GET'])
@requires_permission("manage_permissions")
def api_get_groups():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM groups")
    groups = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jsonify(groups), 200

@app.route('/api/groups', methods=['POST'])
@requires_permission("manage_permissions")
def api_create_group():
    data = request.get_json() or {}
    name = data.get("name", "").strip()
    description = data.get("description", "")
    creator = data.get("creator", "")
    if not name or not creator:
        return jsonify({"error": "Group name and creator are required"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO groups (name, description, creator) VALUES (?, ?, ?)", (name, description, creator))
    conn.commit()
    new_id = cursor.lastrowid
    cursor.execute("SELECT * FROM groups WHERE id=?", (new_id,))
    group = dict(cursor.fetchone())
    conn.close()
    # Also add the creator as admin in user_groups
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO user_groups (username, group_id, role) VALUES (?, ?, ?)", (creator, new_id, "admin"))
    conn.commit()
    conn.close()
    return jsonify(group), 201

@app.route('/api/users/<username>/groups', methods=['GET'])
@requires_permission("manage_permissions")
def api_get_user_groups(username):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT g.*, ug.role FROM groups g 
        JOIN user_groups ug ON g.id = ug.group_id 
        WHERE ug.username=?
    """, (username,))
    groups = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jsonify(groups), 200

@app.route('/api/users/<username>/groups', methods=['POST'])
@requires_permission("manage_permissions")
def api_assign_group_to_user(username):
    data = request.get_json() or {}
    group_id = data.get("group_id")
    if not group_id:
        return jsonify({"error": "Group ID is required"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO user_groups (username, group_id, role) VALUES (?, ?, ?)", (username, group_id, "user"))
    conn.commit()
    conn.close()
    return jsonify({"status": "ok", "message": "Group assigned to user"}), 200

@app.route('/api/groups/<int:group_id>/invite', methods=['POST'])
@requires_permission("manage_permissions")
def api_invite_user_to_group(group_id):
    data = request.get_json() or {}
    invitee = data.get("invitee", "").strip()
    if not invitee:
        return jsonify({"error": "Invitee username is required"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO user_groups (username, group_id, role) VALUES (?, ?, ?)", (invitee, group_id, "user"))
    conn.commit()
    conn.close()
    return jsonify({"status": "ok", "message": f"User {invitee} invited to group {group_id}"}), 200

@app.route('/api/groups/<int:group_id>/users/<username>', methods=['PUT'])
@requires_permission("manage_permissions")
def api_update_user_role_in_group(group_id, username):
    data = request.get_json() or {}
    role = data.get("role", "").strip()
    if role not in ["user", "editor", "admin"]:
        return jsonify({"error": "Invalid role"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE user_groups SET role=? WHERE group_id=? AND username=?", (role, group_id, username))
    conn.commit()
    conn.close()
    return jsonify({"status": "ok", "message": "User role updated"}), 200

@app.route('/api/groups/export', methods=['GET'])
@requires_permission("manage_permissions")
def api_export_groups():
    username = request.args.get("username")
    if not username:
        return jsonify({"error": "Username is required"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM groups g 
        JOIN user_groups ug ON g.id = ug.group_id 
        WHERE ug.username=?
    """, (username,))
    groups = [dict(row) for row in cursor.fetchall()]
    export_data = {"groups": groups, "data": {}}
    for group in groups:
        group_id = group["id"]
        cursor.execute("SELECT * FROM tasks WHERE group_id=?", (group_id,))
        tasks = [dict(row) for row in cursor.fetchall()]
        cursor.execute("SELECT * FROM projects WHERE group_id=?", (group_id,))
        projects = [dict(row) for row in cursor.fetchall()]
        cursor.execute("SELECT * FROM sops WHERE group_id=?", (group_id,))
        sops = [dict(row) for row in cursor.fetchall()]
        export_data["data"][group_id] = {
            "tasks": tasks,
            "projects": projects,
            "sops": sops
        }
    conn.close()
    return jsonify(export_data), 200

@app.route('/api/groups/import', methods=['POST'])
@requires_permission("manage_permissions")
def api_import_groups():
    data = request.get_json() or {}
    username = data.get("username")
    if not username:
        return jsonify({"error": "Username is required for import"}), 400
    imported_data = data.get("data")
    if not imported_data:
        return jsonify({"error": "No group data provided"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    for group_id_str, group_data in imported_data.items():
        for task in group_data.get("tasks", []):
            cursor.execute("""
                INSERT INTO tasks (title, assigned_to, creation_date, due_date, completed, recurring, frequency_hours, always_assigned, group_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                task["title"],
                task["assigned_to"],
                task["creation_date"],
                task["due_date"],
                task["completed"],
                task["recurring"],
                task["frequency_hours"],
                task["always_assigned"],
                group_id_str
            ))
        for project in group_data.get("projects", []):
            cursor.execute("""
                INSERT INTO projects (name, description, created_by, creation_date, group_id)
                VALUES (?, ?, ?, ?, ?)
            """, (
                project["name"],
                project["description"],
                project["created_by"],
                project["creation_date"],
                group_id_str
            ))
        for sop in group_data.get("sops", []):
            cursor.execute("""
                INSERT INTO sops (title, content, version, published_date, effective_date, group_id)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                sop["title"],
                sop["content"],
                sop["version"],
                sop["published_date"],
                sop["effective_date"],
                group_id_str
            ))
    conn.commit()
    conn.close()
    return jsonify({"status": "ok", "message": "Import successful"}), 200

# ---------------- SOP Management Endpoints ----------------

@app.route('/api/sops', methods=['GET'])
@requires_permission("manage_sops")
def api_get_sops():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM sops")
    sops = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jsonify(sops), 200

@app.route('/api/sops', methods=['POST'])
@requires_permission("manage_sops")
def api_create_sop():
    data = request.get_json() or {}
    title = data.get("title", "").strip()
    content = data.get("content", "")
    version = data.get("version", "").strip()
    published_date = datetime.utcnow().isoformat()
    effective_date = data.get("effective_date", published_date)
    group_id = data.get("group_id")
    if not title or not version or not group_id:
        return jsonify({"error": "Title, version and group_id are required for SOP"}), 400
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO sops (title, content, version, published_date, effective_date, group_id)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (title, content, version, published_date, effective_date, group_id))
    conn.commit()
    new_id = cursor.lastrowid
    cursor.execute("SELECT * FROM sops WHERE id=?", (new_id,))
    sop = dict(cursor.fetchone())
    conn.close()
    return jsonify(sop), 201

@app.route('/api/sop_agreement', methods=['POST'])
def api_agree_sop():
    username = session.get("username")
    if not username:
        return jsonify({"error": "Not authenticated"}), 401
    data = request.get_json() or {}
    sop_id = data.get("sop_id")
    sop_version = data.get("sop_version", "").strip()
    if not sop_id or not sop_version:
        return jsonify({"error": "sop_id and sop_version are required"}), 400
    agreed_at = datetime.utcnow().isoformat()
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM sop_agreements WHERE username=? AND sop_id=?", (username, sop_id))
    existing = cursor.fetchone()
    if existing:
        cursor.execute("UPDATE sop_agreements SET agreed_at=?, sop_version=? WHERE id=?", (agreed_at, sop_version, existing["id"]))
    else:
        cursor.execute("INSERT INTO sop_agreements (sop_id, username, agreed_at, sop_version) VALUES (?, ?, ?, ?)", (sop_id, username, agreed_at, sop_version))
    conn.commit()
    conn.close()
    log(f"[api_agree_sop] User '{username}' agreed to SOP {sop_id} version {sop_version} at {agreed_at}")
    return jsonify({"status": "ok", "message": "SOP agreed"}), 200

# ---------------- Notification Endpoints ----------------

@app.route('/api/register_token', methods=['POST'])
def register_token():
    data = request.get_json(silent=True) or {}
    token = data.get("token", "").strip()
    username = data.get("username", "").strip()
    if not token or not username:
        return jsonify({"error": "Missing token or username"}), 400
    log(f"[register_token] Received token for user {username}: {token}")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM device_tokens WHERE username=? AND token=?", (username, token))
    row = cursor.fetchone()
    if row:
        log("[register_token] Token already exists. No change.")
    else:
        cursor.execute("INSERT INTO device_tokens (username, token) VALUES (?,?)", (username, token))
        conn.commit()
        log("[register_token] New token stored.")
    conn.close()
    return jsonify({"status": "ok"}), 200

# -------------------- PROJECTS ENDPOINTS --------------------

@app.route('/api/projects', methods=['GET'])
def api_get_projects():
    log("[api/projects] Fetching projects...")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM projects")
    projects_rows = cursor.fetchall()
    projects_list = []
    for proj in projects_rows:
        proj_dict = {
            "id": proj["id"],
            "name": proj["name"],
            "description": proj["description"],
            "created_by": proj["created_by"],
            "creation_date": proj["creation_date"],
            "todos": []
        }
        cursor.execute("SELECT * FROM project_todos WHERE project_id=?", (proj["id"],))
        todos = cursor.fetchall()
        for todo in todos:
            proj_dict["todos"].append({
                "id": todo["id"],
                "title": todo["title"],
                "description": todo["description"],
                "due_date": todo["due_date"],
                "is_task": todo["is_task"],
                "assigned_to": todo["assigned_to"],
                "points": todo["points"],
                "creation_date": todo["creation_date"],
                "completed": todo["completed"],
                "completed_by": todo["completed_by"],
                "completed_on": todo["completed_on"]
            })
        projects_list.append(proj_dict)
    conn.close()
    log(f"[api/projects] Found {len(projects_list)} projects")
    return jsonify(projects_list), 200

@app.route('/api/projects', methods=['POST'])
def api_create_project():
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "Project name is required"}), 400
    name = data["name"]
    description = data.get("description", "")
    created_by = data.get("created_by", "Unknown")
    creation_date = datetime.utcnow().isoformat()
    log(f"[api/create_project] Creating project: name={name}, created_by={created_by}")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO projects (name, description, created_by, creation_date)
        VALUES (?, ?, ?, ?)
    """, (name, description, created_by, creation_date))
    conn.commit()
    new_id = cursor.lastrowid
    cursor.execute("SELECT * FROM projects WHERE id=?", (new_id,))
    proj = cursor.fetchone()
    conn.close()
    project = {
        "id": proj["id"],
        "name": proj["name"],
        "description": proj["description"],
        "created_by": proj["created_by"],
        "creation_date": proj["creation_date"]
    }
    log(f"[api/create_project] Project created with id={new_id}")
    return jsonify(project), 201

@app.route('/api/projects/<int:project_id>/todos', methods=['POST'])
def api_create_project_todo(project_id):
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "Todo title is required"}), 400
    title = data["title"]
    description = data.get("description", "")
    due_date = data.get("due_date", None)
    points = data.get("points", 0)
    creation_date = datetime.utcnow().isoformat()
    log(f"[api/create_project_todo] Creating todo in project {project_id}: title={title}, due_date={due_date}, points={points}")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO project_todos (project_id, title, description, due_date, points, creation_date)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (project_id, title, description, due_date, points, creation_date))
    conn.commit()
    new_id = cursor.lastrowid
    cursor.execute("SELECT * FROM project_todos WHERE id=?", (new_id,))
    todo = cursor.fetchone()
    conn.close()
    todo_dict = {
        "id": todo["id"],
        "project_id": todo["project_id"],
        "title": todo["title"],
        "description": todo["description"],
        "due_date": todo["due_date"],
        "is_task": todo["is_task"],
        "assigned_to": todo["assigned_to"],
        "points": todo["points"],
        "creation_date": todo["creation_date"],
        "completed": todo["completed"],
        "completed_by": todo["completed_by"],
        "completed_on": todo["completed_on"]
    }
    log(f"[api/create_project_todo] Todo created with id={new_id} in project {project_id}")
    return jsonify(todo_dict), 201

@app.route('/api/projects/<int:project_id>/todos/<int:todo_id>/convert', methods=['POST'])
def api_convert_project_todo(project_id, todo_id):
    data = request.get_json()
    if not data or "assigned_to" not in data or "duration_hours" not in data or "points" not in data:
        return jsonify({"error": "assigned_to, duration_hours, and points are required"}), 400
    assigned_to = data["assigned_to"]
    duration_hours = int(data["duration_hours"])
    points = int(data["points"])
    log(f"[api/convert_project_todo] Converting todo {todo_id} in project {project_id} to aufgabe: assigned_to={assigned_to}, duration_hours={duration_hours}, points={points}")
    creation_date = datetime.utcnow()
    due_date = creation_date + timedelta(hours=duration_hours)
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE project_todos
        SET is_task=1, assigned_to=?, due_date=?, points=?
        WHERE id=? AND project_id=?
    """, (assigned_to, due_date.isoformat(), points, todo_id, project_id))
    conn.commit()
    cursor.execute("SELECT * FROM project_todos WHERE id=? AND project_id=?", (todo_id, project_id))
    todo = cursor.fetchone()
    conn.close()
    todo_dict = {
        "id": todo["id"],
        "project_id": todo["project_id"],
        "title": todo["title"],
        "description": todo["description"],
        "due_date": todo["due_date"],
        "is_task": todo["is_task"],
        "assigned_to": todo["assigned_to"],
        "points": todo["points"],
        "creation_date": todo["creation_date"],
        "completed": todo["completed"],
        "completed_by": todo["completed_by"],
        "completed_on": todo["completed_on"]
    }
    log(f"[api/convert_project_todo] Todo {todo_id} converted to aufgabe in project {project_id}")
    return jsonify(todo_dict), 200

@app.route('/api/projects/export_csv', methods=['GET'])
def api_export_projects_csv():
    log("[api/projects/export_csv] Exporting projects as CSV...")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM projects")
    projects = cursor.fetchall()
    si = io.StringIO()
    cw = csv.writer(si)
    cw.writerow(["id", "name", "description", "created_by", "creation_date"])
    for proj in projects:
        cw.writerow([proj["id"], proj["name"], proj["description"], proj["created_by"], proj["creation_date"]])
    conn.close()
    output = io.BytesIO()
    output.write(si.getvalue().encode("utf-8"))
    output.seek(0)
    return send_file(output, mimetype="text/csv", as_attachment=True, download_name="projects.csv")

@app.route('/api/projects/export_xlsx', methods=['GET'])
def api_export_projects_xlsx():
    log("[api/projects/export_xlsx] Exporting projects as XLSX...")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM projects")
    projects = cursor.fetchall()
    si = io.StringIO()
    cw = csv.writer(si)
    cw.writerow(["id", "name", "description", "created_by", "creation_date"])
    for proj in projects:
        cw.writerow([proj["id"], proj["name"], proj["description"], proj["created_by"], proj["creation_date"]])
    conn.close()
    output = io.BytesIO()
    output.write(si.getvalue().encode("utf-8"))
    output.seek(0)
    return send_file(output, mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", as_attachment=True, download_name="projects.xlsx")

# ---------------- FLUTTER / MOBILE API (Duplicate endpoints) ----------------

@app.route('/api/heartbeat', methods=['GET'])
def api_heartbeat_duplicate():
    log("[api/heartbeat] Called")
    return jsonify({"status": "ok"}), 200

@app.route('/api/request_otp', methods=['POST'])
def api_request_otp():
    data = request.get_json() or {}
    raw_phone = data.get("phone", "").strip()
    log(f"[api/request_otp] raw_phone={raw_phone}")
    if not raw_phone:
        return jsonify({"status": "error", "message": "No phone provided"}), 400
    phone = normalize_phone(raw_phone)
    code = generate_otp_code()
    expires_at = datetime.utcnow() + timedelta(minutes=5)
    pending_otps[phone] = {"code": code, "expires": expires_at}
    log(f"[api/request_otp] Generated OTP for phone {phone} with code {code} (expires at {expires_at.isoformat()})")
    send_otp_sms(phone, code)
    return jsonify({"status": "otp_sent"}), 200

@app.route('/api/verify_otp', methods=['POST'])
def api_verify_otp():
    data = request.get_json() or {}
    raw_phone = data.get("phone", "").strip()
    otp_code = data.get("otp_code", "").strip()
    log(f"[api/verify_otp] raw_phone={raw_phone}, otp_code={otp_code}")
    if not raw_phone or not otp_code:
        return jsonify({"status": "error", "message": "Missing phone or otp_code"}), 400
    phone = normalize_phone(raw_phone)
    entry = pending_otps.get(phone)
    if not entry:
        log(f"[api/verify_otp] No OTP pending for phone {phone}")
        return jsonify({"status": "fail", "message": "No OTP pending"}), 401
    if datetime.utcnow() > entry["expires"]:
        log(f"[api/verify_otp] OTP expired for phone {phone}")
        del pending_otps[phone]
        return jsonify({"status": "fail", "message": "OTP expired"}), 401
    if otp_code != entry["code"]:
        log(f"[api/verify_otp] Incorrect OTP for phone {phone}")
        return jsonify({"status": "fail", "message": "Incorrect code"}), 401
    del pending_otps[phone]
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT username FROM users WHERE phone=?", (phone,))
    row = cursor.fetchone()
    conn.close()
    if row:
        username = row["username"]
        session['username'] = username
        log(f"[api/verify_otp] User exists. Logging in as {username}")
        return jsonify({"status": "ok", "username": username}), 200
    else:
        log(f"[api/verify_otp] No user registered for phone {phone}. Registration required.")
        return jsonify({"status": "registration_required", "phone": phone}), 200

@app.route('/api/register', methods=['POST'])
def api_register():
    data = request.get_json() or {}
    phone = data.get("phone", "").strip()
    username = data.get("username", "").strip()
    log(f"[api/register] Attempting to register phone={phone} with username={username}")
    if not phone or not username:
        return jsonify({"status": "error", "message": "Missing phone or username"}), 400
    phone = normalize_phone(phone)
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE phone=?", (phone,))
    if cursor.fetchone():
        conn.close()
        log(f"[api/register] User with phone {phone} already registered.")
        return jsonify({"status": "error", "message": "User already registered"}), 400
    cursor.execute("INSERT INTO users (phone, username) VALUES (?,?)", (phone, username))
    conn.commit()
    conn.close()
    session['username'] = username
    log(f"[api/register] Registered new user: {username} with phone {phone}")
    return jsonify({"status": "ok", "username": username}), 200

# ---------------- Run the App ----------------

init_db()

if __name__ == '__main__':
    log("Starting Flask server on port 5444...")
    app.run(debug=True, port=5444)
