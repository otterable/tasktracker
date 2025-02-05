import os
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
import requests

from flask_cors import CORS
from twilio.rest import Client
import firebase_admin
from firebase_admin import credentials, messaging

app = Flask(__name__)
app.secret_key = "my-very-strong-secret-key"  # Change this to something secure
CORS(app)

DATABASE = os.path.join(app.root_path, 'database.db')
LIVE_BASE_URL = "https://molentracker.ermine.at"

######################### TWILIO CONFIGURATION #########################
TWILIO_ACCOUNT_SID = "ACc21e0ab649ebe0280c1cab26ebdb92be"
TWILIO_AUTH_TOKEN = "4799cd1a4a179d21f1fc1083aab66736"
TWILIO_FROM_NUMBER = "+14243294447"
#########################################################################

PHONE_TO_USERNAME = {
    "+436703596614": "otter",
    "+4369910503659": "weasel"
}

pending_otps = {}

# ----- Firebase Admin Initialization -----
try:
    cred = credentials.Certificate("service-account.json")
    firebase_admin.initialize_app(cred)
    log_msg = "Firebase Admin initialized successfully."
except Exception as e:
    log_msg = f"Error initializing Firebase Admin: {e}"
print(f"[DEBUG] {log_msg}")

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

def requires_permission(permission_name):
    def decorator(f):
        def wrapper(*args, **kwargs):
            data = request.get_json(silent=True) or {}
            log(f"[requires_permission] Request JSON: {data}")
            username = session.get('username')
            if not username:
                username = data.get("creator")
                if username:
                    session['username'] = username
                    log(f"[requires_permission] Set session username from request data: {username}")
                else:
                    log("[requires_permission] Not authenticated: No session and no creator provided in request")
                    return jsonify({"error": "Not authenticated"}), 401
            log(f"[requires_permission] Authenticated as: {session.get('username')}")
            user_perms = get_user_permissions(session.get('username'))
            log(f"[requires_permission] Permissions for {session.get('username')}: {user_perms}")
            if permission_name not in user_perms:
                log(f"[requires_permission] Permission '{permission_name}' required, but user '{session.get('username')}' permissions: {user_perms}")
                return jsonify({"error": "Permission denied", "required": permission_name}), 403
            return f(*args, **kwargs)
        wrapper.__name__ = f.__name__
        return wrapper
    return decorator

def get_user_permissions(username: str) -> set:
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

def create_table_if_not_exists(cursor, table_name, create_sql):
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table_name,))
    result = cursor.fetchone()
    if result is None:
        log(f"Table '{table_name}' does not exist. Creating it with SQL: {create_sql}")
        cursor.execute(create_sql)
        log(f"Table '{table_name}' created.")
    else:
        log(f"Table '{table_name}' already exists.")

def init_db():
    log("Initializing database...")
    new_db = not os.path.exists(DATABASE)
    conn = get_db_connection()
    cursor = conn.cursor()

    if new_db:
        log("No database file found. Creating all tables.")
    else:
        log("Database file exists. Running CREATE TABLE IF NOT EXISTS for all tables.")

    # Create tasks table (now with project_id)
    create_table_if_not_exists(cursor, "tasks", '''
        CREATE TABLE tasks (
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
            group_id TEXT,
            project_id INTEGER
        )
    ''')
    # Create device_tokens table
    create_table_if_not_exists(cursor, "device_tokens", '''
        CREATE TABLE device_tokens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            token TEXT
        )
    ''')
    # Create projects table
    create_table_if_not_exists(cursor, "projects", '''
        CREATE TABLE projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_by TEXT,
            creation_date TEXT,
            group_id TEXT
        )
    ''')
    # Create project_todos table
    create_table_if_not_exists(cursor, "project_todos", '''
        CREATE TABLE project_todos (
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
    # Create project_assignments table (new)
    create_table_if_not_exists(cursor, "project_assignments", '''
        CREATE TABLE project_assignments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            username TEXT NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        )
    ''')
    # Create users table
    create_table_if_not_exists(cursor, "users", '''
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT UNIQUE NOT NULL,
            username TEXT UNIQUE NOT NULL
        )
    ''')
    # Create groups table
    create_table_if_not_exists(cursor, "groups", '''
        CREATE TABLE groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            creator TEXT
        )
    ''')
    # Create permissions table
    create_table_if_not_exists(cursor, "permissions", '''
        CREATE TABLE permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT
        )
    ''')
    # Create group_permissions mapping table
    create_table_if_not_exists(cursor, "group_permissions", '''
        CREATE TABLE group_permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            permission_id INTEGER NOT NULL,
            FOREIGN KEY(group_id) REFERENCES groups(id),
            FOREIGN KEY(permission_id) REFERENCES permissions(id)
        )
    ''')
    # Create user_groups mapping table
    create_table_if_not_exists(cursor, "user_groups", '''
        CREATE TABLE user_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            group_id INTEGER NOT NULL,
            role TEXT DEFAULT 'user',
            FOREIGN KEY(group_id) REFERENCES groups(id)
        )
    ''')
    # Create sops table
    create_table_if_not_exists(cursor, "sops", '''
        CREATE TABLE sops (
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
    create_table_if_not_exists(cursor, "sop_agreements", '''
        CREATE TABLE sop_agreements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sop_id INTEGER NOT NULL,
            username TEXT NOT NULL,
            agreed_at TEXT,
            sop_version TEXT NOT NULL,
            FOREIGN KEY(sop_id) REFERENCES sops(id)
        )
    ''')
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

@app.after_request
def add_header(response):
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    return response

# ---------------- API Endpoints ----------------

# --- Permissions Endpoints ---
@app.route('/api/permissions', methods=['GET'])
@requires_permission("manage_permissions")
def api_get_permissions():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM permissions")
    perms = [dict(row) for row in cursor.fetchall()]
    conn.close()
    log(f"[api_get_permissions] Returning {len(perms)} permissions")
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
    log(f"[api_create_permission] Created permission: {perm}")
    return jsonify(perm), 201

# --- Groups and User-Group Endpoints ---
@app.route('/api/groups', methods=['POST'])
def api_create_group():
    try:
        data = request.get_json() or {}
        log(f"[api_create_group] Received data: {data}")
        name = data.get("name", "").strip()
        description = data.get("description", "")
        creator = data.get("creator", "").strip()
        if not name or not creator:
            log("[api_create_group] Missing group name or creator.")
            return jsonify({"error": "Group name and creator are required"}), 400

        if not session.get("username"):
            session["username"] = creator
            log(f"[api_create_group] Session username set to: {creator}")

        conn = get_db_connection()
        cursor = conn.cursor()
        log(f"[api_create_group] Checking for duplicate group with name: {name}")
        try:
            cursor.execute("SELECT * FROM groups WHERE name=?", (name,))
        except sqlite3.OperationalError as err:
            if "no such table" in str(err):
                log("[api_create_group] Groups table missing. Recreating it now.")
                cursor.execute('''
                    CREATE TABLE groups (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT UNIQUE NOT NULL,
                        description TEXT,
                        creator TEXT
                    )
                ''')
                conn.commit()
                cursor.execute("SELECT * FROM groups WHERE name=?", (name,))
            else:
                raise
        existing_group = cursor.fetchone()
        if existing_group:
            log(f"[api_create_group] Group with name '{name}' already exists.")
            conn.close()
            return jsonify({"error": "Group with this name already exists"}), 400

        log(f"[api_create_group] Inserting group into database with name: {name}, description: {description}, creator: {creator}")
        cursor.execute("INSERT INTO groups (name, description, creator) VALUES (?, ?, ?)", (name, description, creator))
        conn.commit()
        new_id = cursor.lastrowid
        log(f"[api_create_group] New group inserted with id: {new_id}")
        cursor.execute("SELECT * FROM groups WHERE id=?", (new_id,))
        group = dict(cursor.fetchone())
        conn.close()

        conn = get_db_connection()
        cursor = conn.cursor()
        log(f"[api_create_group] Inserting into user_groups: username={creator}, group_id={new_id}, role=admin")
        cursor.execute("INSERT INTO user_groups (username, group_id, role) VALUES (?, ?, ?)", (creator, new_id, "admin"))
        conn.commit()
        conn.close()
        log(f"[api_create_group] Group created successfully with id={new_id} by {creator}")
        return jsonify(group), 201
    except Exception as e:
        log(f"[api_create_group] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during group creation"}), 500

@app.route('/api/users/<username>/groups', methods=['GET'])
def api_get_user_groups(username):
    try:
        log(f"[api_get_user_groups] Request for groups for user: {username}")
        log(f"[api_get_user_groups] Session contents: {dict(session)}")
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT g.*, ug.role FROM groups g 
            JOIN user_groups ug ON g.id = ug.group_id 
            WHERE ug.username=?
        """, (username,))
        groups = [dict(row) for row in cursor.fetchall()]
        conn.close()
        log(f"[api_get_user_groups] Returning {len(groups)} groups for {username}")
        return jsonify(groups), 200
    except Exception as e:
        log(f"[api_get_user_groups] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during fetching user groups"}), 500

@app.route('/api/users/<username>/groups', methods=['POST'])
@requires_permission("manage_permissions")
def api_assign_group_to_user(username):
    try:
        data = request.get_json() or {}
        group_id = data.get("group_id")
        if not group_id:
            log("[api_assign_group_to_user] Group ID missing in request data.")
            return jsonify({"error": "Group ID is required"}), 400
        conn = get_db_connection()
        cursor = conn.cursor()
        log(f"[api_assign_group_to_user] Assigning group {group_id} to user {username}")
        cursor.execute("INSERT INTO user_groups (username, group_id, role) VALUES (?, ?, ?)", (username, group_id, "user"))
        conn.commit()
        conn.close()
        log(f"[api_assign_group_to_user] Assigned group {group_id} to user {username}")
        return jsonify({"status": "ok", "message": "Group assigned to user"}), 200
    except Exception as e:
        log(f"[api_assign_group_to_user] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during assigning group"}), 500

@app.route('/api/groups/<int:group_id>/invite', methods=['POST'])
@requires_permission("manage_permissions")
def api_invite_user_to_group(group_id):
    try:
        data = request.get_json() or {}
        invitee = data.get("invitee", "").strip()
        if not invitee:
            log("[api_invite_user_to_group] Missing invitee username.")
            return jsonify({"error": "Invitee username is required"}), 400
        conn = get_db_connection()
        cursor = conn.cursor()
        log(f"[api_invite_user_to_group] Inviting user {invitee} to group {group_id}")
        cursor.execute("INSERT INTO user_groups (username, group_id, role) VALUES (?, ?, ?)", (invitee, group_id, "user"))
        conn.commit()
        conn.close()
        log(f"[api_invite_user_to_group] Invited user {invitee} to group {group_id}")
        return jsonify({"status": "ok", "message": f"User {invitee} invited to group {group_id}"}), 200
    except Exception as e:
        log(f"[api_invite_user_to_group] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during inviting user"}), 500

@app.route('/api/groups/<int:group_id>/users/<username>', methods=['PUT'])
@requires_permission("manage_permissions")
def api_update_user_role_in_group(group_id, username):
    try:
        data = request.get_json() or {}
        role = data.get("role", "").strip()
        if role not in ["user", "editor", "admin"]:
            log(f"[api_update_user_role_in_group] Invalid role: {role}")
            return jsonify({"error": "Invalid role"}), 400
        conn = get_db_connection()
        cursor = conn.cursor()
        log(f"[api_update_user_role_in_group] Updating role for user {username} in group {group_id} to {role}")
        cursor.execute("UPDATE user_groups SET role=? WHERE group_id=? AND username=?", (role, group_id, username))
        conn.commit()
        conn.close()
        log(f"[api_update_user_role_in_group] Updated role for user {username} in group {group_id} to {role}")
        return jsonify({"status": "ok", "message": "User role updated"}), 200
    except Exception as e:
        log(f"[api_update_user_role_in_group] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during updating user role"}), 500

@app.route('/api/groups/export', methods=['GET'])
@requires_permission("manage_permissions")
def api_export_groups():
    try:
        username = request.args.get("username")
        if not username:
            log("[api_export_groups] Username is required for export.")
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
        log(f"[api_export_groups] Exported data for user {username}")
        return jsonify(export_data), 200
    except Exception as e:
        log(f"[api_export_groups] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during exporting groups"}), 500

@app.route('/api/groups/import', methods=['POST'])
@requires_permission("manage_permissions")
def api_import_groups():
    try:
        data = request.get_json() or {}
        username = data.get("username")
        if not username:
            log("[api_import_groups] Username missing in import data.")
            return jsonify({"error": "Username is required for import"}), 400
        imported_data = data.get("data")
        if not imported_data:
            log("[api_import_groups] No group data provided for import.")
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
        log("[api_import_groups] Import successful")
        return jsonify({"status": "ok", "message": "Import successful"}), 200
    except Exception as e:
        log(f"[api_import_groups] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during importing groups"}), 500

@app.route('/api/groups/<group_id>/members', methods=['GET'])
def api_get_group_members(group_id):
    try:
        log(f"[api_get_group_members] Fetching members for group id: {group_id}")
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT username, role FROM user_groups WHERE group_id=?", (group_id,))
        members = [dict(row) for row in cursor.fetchall()]
        conn.close()
        log(f"[api_get_group_members] Found {len(members)} members for group id: {group_id}")
        return jsonify(members), 200
    except Exception as e:
        log(f"[api_get_group_members] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during fetching group members"}), 500

# --- Tasks Endpoints ---

@app.route('/api/tasks/recurring', methods=['POST'])
def api_create_recurring_task():
    try:
        data = request.get_json() or {}
        log(f"[api_create_recurring_task] Received data: {data}")
        title = data.get("title", "").strip()
        group_id = data.get("group_id", "").strip()
        duration_hours = data.get("duration_hours")
        assigned_to = data.get("assigned_to")
        frequency_hours = data.get("frequency_hours")
        always_assigned = data.get("always_assigned", True)
        project_id = data.get("project_id")  # optional

        if not title or not group_id or duration_hours is None or frequency_hours is None:
            log("[api_create_recurring_task] Missing required parameters")
            return jsonify({"error": "Missing required parameters"}), 400

        try:
            duration_hours = int(duration_hours)
            frequency_hours = int(frequency_hours)
        except ValueError:
            log("[api_create_recurring_task] duration_hours and frequency_hours must be integers")
            return jsonify({"error": "duration_hours and frequency_hours must be integers"}), 400

        creation_date = datetime.utcnow().isoformat()
        due_date = (datetime.utcnow() + timedelta(hours=duration_hours)).isoformat()
        log(f"[api_create_recurring_task] Creating recurring task with title='{title}', creation_date='{creation_date}', due_date='{due_date}', frequency_hours={frequency_hours}, always_assigned={always_assigned}")

        completed = 0
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO tasks 
            (title, assigned_to, creation_date, due_date, completed, recurring, group_id, frequency_hours, always_assigned, project_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (title, assigned_to, creation_date, due_date, completed, 1, group_id, frequency_hours, int(always_assigned), project_id))
        conn.commit()
        new_id = cursor.lastrowid
        log(f"[api_create_recurring_task] Recurring task inserted with id={new_id}")

        cursor.execute("SELECT * FROM tasks WHERE id=?", (new_id,))
        row = cursor.fetchone()
        conn.close()

        if row is None:
            log("[api_create_recurring_task] No row returned after insert")
            return jsonify({"error": "Task creation failed: no row returned"}), 500

        task = {
            "id": row["id"],
            "title": row["title"],
            "assigned_to": row["assigned_to"],
            "creation_date": row["creation_date"],
            "due_date": row["due_date"],
            "completed": row["completed"],
            "completed_by": row["completed_by"],
            "completed_on": row["completed_on"],
            "recurring": bool(row["recurring"]),
            "frequency_hours": row["frequency_hours"],
            "always_assigned": bool(row["always_assigned"]),
            "group_id": row["group_id"],
            "project_id": row["project_id"]
        }
        log(f"[api_create_recurring_task] Successfully created recurring task: {task}")
        return jsonify(task), 201

    except Exception as e:
        log(f"[api_create_recurring_task] Exception occurred: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route('/api/tasks', methods=['GET'], endpoint='api_get_tasks')
def api_get_tasks():
    group_id = request.args.get("group_id")
    log(f"[api_get_tasks] Request received for group_id: {group_id}")
    if not group_id:
        log("[api_get_tasks] Missing group_id parameter")
        return jsonify({"error": "Missing group_id parameter"}), 400
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tasks WHERE group_id=?", (group_id,))
        rows = cursor.fetchall()
        tasks = [dict(row) for row in rows]
        conn.close()
        log(f"[api_get_tasks] Returning {len(tasks)} tasks for group {group_id}")
        return jsonify(tasks), 200
    except Exception as e:
        log(f"[api_get_tasks] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during fetching tasks"}), 500

@app.route('/api/tasks', methods=['POST'], endpoint='api_create_task')
def api_create_task():
    try:
        data = request.get_json() or {}
        log(f"[api_create_task] Received data: {data}")
        title = data.get("title", "").strip()
        group_id = data.get("group_id", "").strip()
        duration_hours = data.get("duration_hours")
        assigned_to = data.get("assigned_to")
        recurring = data.get("recurring", False)
        project_id = data.get("project_id")  # optional

        if not title or not group_id or duration_hours is None:
            log("[api_create_task] Missing required parameters: title, group_id, or duration_hours")
            return jsonify({"error": "Missing required parameters"}), 400

        try:
            duration_hours = int(duration_hours)
        except ValueError:
            log("[api_create_task] duration_hours must be an integer")
            return jsonify({"error": "duration_hours must be an integer"}), 400

        creation_date = datetime.utcnow().isoformat()
        due_date = (datetime.utcnow() + timedelta(hours=duration_hours)).isoformat()
        log(f"[api_create_task] Creating task with title='{title}', creation_date='{creation_date}', due_date='{due_date}', recurring='{recurring}'")

        completed = 0
        frequency_hours = None
        always_assigned = 1

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO tasks 
            (title, assigned_to, creation_date, due_date, completed, recurring, group_id, frequency_hours, always_assigned, project_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (title, assigned_to, creation_date, due_date, completed, int(recurring), group_id, frequency_hours, always_assigned, project_id))
        conn.commit()
        new_id = cursor.lastrowid
        log(f"[api_create_task] Task inserted with id={new_id}")

        cursor.execute("SELECT * FROM tasks WHERE id=?", (new_id,))
        row = cursor.fetchone()
        conn.close()

        if row is None:
            log("[api_create_task] No row returned after insert")
            return jsonify({"error": "Task creation failed: no row returned"}), 500

        task = {
            "id": row["id"],
            "title": row["title"],
            "assigned_to": row["assigned_to"],
            "creation_date": row["creation_date"],
            "due_date": row["due_date"],
            "completed": row["completed"],
            "completed_by": row["completed_by"],
            "completed_on": row["completed_on"],
            "recurring": bool(row["recurring"]),
            "frequency_hours": row["frequency_hours"],
            "always_assigned": bool(row["always_assigned"]),
            "group_id": row["group_id"],
            "project_id": row["project_id"]
        }
        log(f"[api_create_task] Successfully created task: {task}")
        return jsonify(task), 201

    except Exception as e:
        log(f"[api_create_task] Exception occurred: {e}")
        return jsonify({"error": "Internal server error"}), 500

# --- SOP Endpoints ---
@app.route('/api/sops', methods=['GET'])
@requires_permission("manage_sops")
def api_get_sops():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM sops")
    sops = [dict(row) for row in cursor.fetchall()]
    conn.close()
    log(f"[api_get_sops] Returning {len(sops)} SOPs")
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
        log("[api_create_sop] Missing title, version or group_id.")
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
    log(f"[api_create_sop] Created SOP with id={new_id}")
    return jsonify(sop), 201

@app.route('/api/sop_agreement', methods=['POST'])
def api_agree_sop():
    username = session.get("username")
    if not username:
        log("[api_agree_sop] Not authenticated.")
        return jsonify({"error": "Not authenticated"}), 401
    data = request.get_json() or {}
    sop_id = data.get("sop_id")
    sop_version = data.get("sop_version", "").strip()
    if not sop_id or not sop_version:
        log("[api_agree_sop] Missing sop_id or sop_version.")
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

# --- Notification Endpoint ---
@app.route('/api/register_token', methods=['POST'])
def register_token():
    data = request.get_json(silent=True) or {}
    token = data.get("token", "").strip()
    username = data.get("username", "").strip()
    if not token or not username:
        log("[register_token] Missing token or username.")
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

# --- Projects Endpoints ---
@app.route('/api/projects', methods=['GET'])
def api_get_projects():
    log("[api/projects] Fetching projects...")
    conn = get_db_connection()
    cursor = conn.cursor()
    group_id = request.args.get("group_id")
    if group_id:
        cursor.execute("SELECT * FROM projects WHERE group_id=?", (group_id,))
    else:
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
            "group_id": proj["group_id"],
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
        # Get project assignments
        cursor.execute("SELECT username FROM project_assignments WHERE project_id=?", (proj["id"],))
        assignments = [row["username"] for row in cursor.fetchall()]
        proj_dict["assignments"] = assignments
        projects_list.append(proj_dict)
    conn.close()
    log(f"[api/projects] Found {len(projects_list)} projects")
    return jsonify(projects_list), 200

@app.route('/api/projects', methods=['POST'])
def api_create_project():
    data = request.get_json()
    if not data or "name" not in data or "group_id" not in data:
        log("[api/create_project] Project name or group_id missing.")
        return jsonify({"error": "Project name and group_id are required"}), 400
    name = data["name"]
    description = data.get("description", "")
    created_by = data.get("created_by", "Unknown")
    creation_date = datetime.utcnow().isoformat()
    log(f"[api/create_project] Creating project: name={name}, created_by={created_by}")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO projects (name, description, created_by, creation_date, group_id)
        VALUES (?, ?, ?, ?, ?)
    """, (name, description, created_by, creation_date, data.get("group_id", "default")))
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
        "creation_date": proj["creation_date"],
        "group_id": proj["group_id"],
        "assignments": []
    }
    log(f"[api/create_project] Project created with id={new_id}")
    return jsonify(project), 201

@app.route('/api/projects/<int:project_id>/todos', methods=['POST'])
def api_create_project_todo(project_id):
    data = request.get_json()
    if not data or "title" not in data:
        log("[api/create_project_todo] Todo title missing.")
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
        log("[api/convert_project_todo] Missing parameters for conversion.")
        return jsonify({"error": "assigned_to, duration_hours, and points are required"}), 400
    assigned_to = data["assigned_to"]
    duration_hours = int(data["duration_hours"])
    points = int(data["points"])
    # Check project assignments – if any exist, the assigned_to must be allowed.
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT username FROM project_assignments WHERE project_id=?", (project_id,))
    allowed = [row["username"] for row in cursor.fetchall()]
    if allowed and (assigned_to not in allowed):
        conn.close()
        log(f"[api/convert_project_todo] Assigned user {assigned_to} is not allowed for project {project_id}. Allowed: {allowed}")
        return jsonify({"error": "User not allowed for this project"}), 403
    log(f"[api/convert_project_todo] Converting todo {todo_id} in project {project_id} to aufgabe: assigned_to={assigned_to}, duration_hours={duration_hours}, points={points}")
    creation_date = datetime.utcnow()
    due_date = creation_date + timedelta(hours=duration_hours)
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
    cw.writerow(["id", "name", "description", "created_by", "creation_date", "group_id"])
    for proj in projects:
        cw.writerow([proj["id"], proj["name"], proj["description"], proj["created_by"], proj["creation_date"], proj["group_id"]])
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
    cw.writerow(["id", "name", "description", "created_by", "creation_date", "group_id"])
    for proj in projects:
        cw.writerow([proj["id"], proj["name"], proj["description"], proj["created_by"], proj["creation_date"], proj["group_id"]])
    conn.close()
    output = io.BytesIO()
    output.write(si.getvalue().encode("utf-8"))
    output.seek(0)
    return send_file(output, mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", as_attachment=True, download_name="projects.xlsx")

# --- New Endpoints for Project Assignments ---

@app.route('/api/projects/<int:project_id>/assignments', methods=['GET'])
def api_get_project_assignments(project_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT username FROM project_assignments WHERE project_id=?", (project_id,))
        rows = cursor.fetchall()
        assignments = [row["username"] for row in rows]
        conn.close()
        log(f"[api_get_project_assignments] Returning assignments for project {project_id}: {assignments}")
        return jsonify(assignments), 200
    except Exception as e:
        log(f"[api_get_project_assignments] Exception: {e}")
        return jsonify({"error": "Internal server error during fetching project assignments"}), 500

@app.route('/api/projects/<int:project_id>/assignments', methods=['POST'])
@requires_permission("assign_projects")
def api_add_project_assignment(project_id):
    try:
        data = request.get_json() or {}
        username = data.get("username")
        if not username:
            return jsonify({"error": "Username required"}), 400
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM project_assignments WHERE project_id=? AND username=?", (project_id, username))
        if cursor.fetchone():
            conn.close()
            return jsonify({"error": "User already assigned"}), 400
        cursor.execute("INSERT INTO project_assignments (project_id, username) VALUES (?, ?)", (project_id, username))
        conn.commit()
        conn.close()
        log(f"[api_add_project_assignment] Added {username} to project {project_id}")
        return jsonify({"status": "ok"}), 201
    except Exception as e:
        log(f"[api_add_project_assignment] Exception: {e}")
        return jsonify({"error": "Internal server error during assigning user to project"}), 500

@app.route('/api/projects/<int:project_id>/assignments/<username>', methods=['DELETE'])
@requires_permission("assign_projects")
def api_remove_project_assignment(project_id, username):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM project_assignments WHERE project_id=? AND username=?", (project_id, username))
        conn.commit()
        conn.close()
        log(f"[api_remove_project_assignment] Removed {username} from project {project_id}")
        return jsonify({"status": "ok"}), 200
    except Exception as e:
        log(f"[api_remove_project_assignment] Exception: {e}")
        return jsonify({"error": "Internal server error during removing project assignment"}), 500

# --- History / Archiving Endpoints ---
@app.route('/api/history', methods=['GET'])
def api_get_history():
    group_id = request.args.get("group_id")
    if not group_id:
        log("[api_get_history] Missing group_id parameter")
        return jsonify({"error": "Missing group_id parameter"}), 400
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tasks WHERE completed = 1 AND group_id=?", (group_id,))
        rows = cursor.fetchall()
        tasks = [dict(row) for row in rows]
        conn.close()
        log(f"[api_get_history] Returning {len(tasks)} archived tasks for group {group_id}")
        return jsonify(tasks), 200
    except Exception as e:
        log(f"[api_get_history] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during fetching history"}), 500

@app.route('/export_history_csv', methods=['GET'])
def export_history_csv():
    group_id = request.args.get("group_id", "default")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tasks WHERE completed = 1 AND group_id=?", (group_id,))
        rows = cursor.fetchall()
        si = io.StringIO()
        cw = csv.writer(si)
        cw.writerow(["id", "title", "assigned_to", "creation_date", "due_date", "completed", "completed_by", "completed_on", "recurring", "frequency_hours", "always_assigned", "group_id", "project_id"])
        for row in rows:
            cw.writerow([
                row["id"],
                row["title"],
                row["assigned_to"],
                row["creation_date"],
                row["due_date"],
                row["completed"],
                row["completed_by"],
                row["completed_on"],
                row["recurring"],
                row["frequency_hours"],
                row["always_assigned"],
                row["group_id"],
                row.get("project_id")
            ])
        conn.close()
        output = io.BytesIO()
        output.write(si.getvalue().encode("utf-8"))
        output.seek(0)
        log(f"[export_history_csv] Exported CSV for group_id {group_id}")
        return send_file(output, mimetype="text/csv", as_attachment=True, download_name="history.csv")
    except Exception as e:
        log(f"[export_history_csv] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during export"}), 500

@app.route('/export_history_xlsx', methods=['GET'])
def export_history_xlsx():
    group_id = request.args.get("group_id", "default")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tasks WHERE completed = 1 AND group_id=?", (group_id,))
        rows = cursor.fetchall()
        si = io.StringIO()
        cw = csv.writer(si)
        cw.writerow(["id", "title", "assigned_to", "creation_date", "due_date", "completed", "completed_by", "completed_on", "recurring", "frequency_hours", "always_assigned", "group_id", "project_id"])
        for row in rows:
            cw.writerow([
                row["id"],
                row["title"],
                row["assigned_to"],
                row["creation_date"],
                row["due_date"],
                row["completed"],
                row["completed_by"],
                row["completed_on"],
                row["recurring"],
                row["frequency_hours"],
                row["always_assigned"],
                row["group_id"],
                row.get("project_id")
            ])
        conn.close()
        output = io.BytesIO()
        output.write(si.getvalue().encode("utf-8"))
        output.seek(0)
        log(f"[export_history_xlsx] Exported XLSX (CSV formatted) for group_id {group_id}")
        return send_file(output, mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", as_attachment=True, download_name="history.xlsx")
    except Exception as e:
        log(f"[export_history_xlsx] Exception occurred: {e}")
        return jsonify({"error": "Internal server error during export"}), 500

# --- Heartbeat, OTP, and Registration Endpoints ---
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

# Force initialization of the database upon module import.
init_db()

if __name__ == '__main__':
    log("Starting Flask server on port 5444...")
    app.run(debug=True, port=5444)
