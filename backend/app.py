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

# Use your live domain for production
LIVE_BASE_URL = "https://molentracker.ermine.at"
DATABASE = 'database.db'

######################### TWILIO CONFIGURATION #########################
TWILIO_ACCOUNT_SID = "ACc21e0ab649ebe0280c1cab26ebdb92be"
TWILIO_AUTH_TOKEN = "4799cd1a4a179d21f1fc1083aab66736"
TWILIO_FROM_NUMBER = "+14243294447"  # Your Twilio phone number

# The phone->username mapping (ensure numbers are normalized)
PHONE_TO_USERNAME = {
    "+436703596614": "otter",
    "+4369910503659": "weasel"
}
#######################################################################

# Dictionary to store OTP requests
pending_otps = {}

# ----- Firebase Admin Initialization ----- 
# Replace the path below with the path to your downloaded service account JSON file.
try:
    cred = credentials.Certificate("path/to/your-service-account-file.json")
    firebase_admin.initialize_app(cred)
    log_msg = "Firebase Admin initialized successfully."
except Exception as e:
    log_msg = f"Error initializing Firebase Admin: {e}"
print(f"[DEBUG] {log_msg}")

# --- No longer need FCM_SERVER_KEY when using firebase_admin ---
# FCM_SERVER_KEY = "YOUR_FIREBASE_SERVER_KEY_HERE"

def normalize_phone(phone: str) -> str:
    """
    Remove all non-digit and non-plus characters.
    Ensure the string starts with '+' if missing.
    """
    p = re.sub(r"[^0-9+]", "", phone)
    if not p.startswith('+'):
        p = '+' + p
    return p

def generate_otp_code() -> str:
    return f"{random.randint(0,999999):06d}"

def send_otp_sms(phone: str, code: str):
    """
    Sends the OTP code via Twilio SMS to the given phone number.
    """
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

def init_db():
    """
    Initializes the database and inserts default tasks if empty.
    """
    log("Initializing database...")
    conn = get_db_connection()
    cursor = conn.cursor()
    # Create tasks table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            assigned_to TEXT,
            creation_date TEXT,
            due_date TEXT,
            completed BOOLEAN DEFAULT 0,
            completed_by TEXT,
            completed_on TEXT
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
    # Insert default tasks if none exist
    cursor.execute('SELECT COUNT(*) as count FROM tasks')
    count_tasks = cursor.fetchone()['count']
    if count_tasks == 0:
        log("No tasks found; inserting default tasks: Wäsche, Küche, kochen.")
        now_str = datetime.utcnow().isoformat()
        cursor.execute("INSERT INTO tasks (title, creation_date) VALUES (?,?)", ("Wäsche", now_str))
        cursor.execute("INSERT INTO tasks (title, creation_date) VALUES (?,?)", ("Küche", now_str))
        cursor.execute("INSERT INTO tasks (title, creation_date) VALUES (?,?)", ("kochen", now_str))
        conn.commit()
    conn.close()
    log("Database init complete.")

@app.route('/')
def index():
    if 'username' in session:
        log(f"Index: user '{session['username']}' is logged in.")
        return redirect(url_for('dashboard'))
    return render_template('index.html')

@app.route('/logout')
def logout():
    log("Logout: Clearing session.")
    session.clear()
    return redirect(url_for('index'))

@app.route('/dashboard')
def dashboard():
    if 'username' not in session:
        return redirect(url_for('index'))
    log(f"Dashboard: Called by user '{session['username']}'")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks WHERE completed=0")
    open_tasks = cursor.fetchall()
    cursor.execute("SELECT * FROM tasks WHERE completed=1")
    completed_tasks = cursor.fetchall()
    conn.close()
    today = datetime.now()
    calendar_days = [today + timedelta(days=i) for i in range(7)]
    return render_template(
        'dashboard.html',
        open_tasks=open_tasks,
        completed_tasks=completed_tasks,
        username=session['username'],
        calendar_days=calendar_days
    )

@app.route('/create_task', methods=['POST'])
def create_task():
    if 'username' not in session:
        return redirect(url_for('index'))
    title = request.form.get('title')
    duration_hours = request.form.get('duration', 48)
    assigned_to = request.form.get('assigned_to', None)
    log(f"[create_task] Creating task: title={title}, duration_hours={duration_hours}, assigned_to={assigned_to}")
    creation_date = datetime.utcnow()
    due_date = creation_date + timedelta(hours=int(duration_hours))
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO tasks (title, assigned_to, creation_date, due_date)
        VALUES (?, ?, ?, ?)
    """, (title, assigned_to, creation_date.isoformat(), due_date.isoformat()))
    conn.commit()
    conn.close()
    # If the task is assigned, send a push notification and schedule reminders.
    if assigned_to:
        send_push_notification_to_user(
            assigned_to,
            f"Neue Aufgabe: {title}",
            f"Fällig bis {due_date.isoformat()}"
        )
        schedule_reminders(title, assigned_to, creation_date, due_date)
    return redirect(url_for('dashboard'))

@app.route('/finish_task/<int:task_id>', methods=['POST'])
def finish_task(task_id):
    if 'username' not in session:
        return redirect(url_for('index'))
    finisher = session['username']
    now = datetime.utcnow()
    log(f"[finish_task] Finishing task id={task_id}, completed_by={finisher}")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE tasks
        SET completed=1, completed_by=?, completed_on=?
        WHERE id=?
    """, (finisher, now.isoformat(), task_id))
    conn.commit()
    cursor.execute("SELECT * FROM tasks WHERE id=?", (task_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        title = row["title"]
        send_push_notification_to_all(
            "Aufgabe erledigt",
            f"'{title}' abgeschlossen von {finisher} am {now.isoformat()}"
        )
    return redirect(url_for('dashboard'))

@app.route('/stats')
def stats():
    if 'username' not in session:
        return redirect(url_for('index'))
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT completed_by, COUNT(*) as total_completed
        FROM tasks
        WHERE completed=1
        GROUP BY completed_by
    """)
    completions = cursor.fetchall()
    cursor.execute("SELECT * FROM tasks ORDER BY creation_date ASC")
    all_tasks = cursor.fetchall()
    conn.close()
    return render_template('stats.html', completions=completions, all_tasks=all_tasks)

@app.route('/export_csv')
def export_csv():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()
    si = io.StringIO()
    cw = csv.writer(si)
    cw.writerow(["id", "title", "assigned_to", "creation_date", "due_date", "completed", "completed_by", "completed_on"])
    for row in rows:
        cw.writerow(list(row))
    output = make_csv_response(si.getvalue(), "tasks.csv")
    return output

@app.route('/export_xlsx')
def export_xlsx():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()
    si = io.StringIO()
    cw = csv.writer(si)
    cw.writerow(["id", "title", "assigned_to", "creation_date", "due_date", "completed", "completed_by", "completed_on"])
    for row in rows:
        cw.writerow(list(row))
    output = make_csv_response(si.getvalue(), "tasks.xlsx")
    return output

def make_csv_response(csv_string, filename):
    output = io.BytesIO()
    output.write(csv_string.encode('utf-8'))
    output.seek(0)
    return send_file(output, mimetype="text/csv", as_attachment=True, download_name=filename)

# ------------------- FLUTTER / MOBILE API ---------------------

@app.route('/api/heartbeat', methods=['GET'])
def api_heartbeat():
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
    if phone not in PHONE_TO_USERNAME:
        return jsonify({"status": "error", "message": "Phone not recognized"}), 404
    code = generate_otp_code()
    expires_at = datetime.utcnow() + timedelta(minutes=5)
    pending_otps[phone] = {"code": code, "expires": expires_at}
    send_otp_sms(phone, code)
    return jsonify({"status": "otp_sent"}), 200

@app.route('/api/verify_otp', methods=['POST'])
def api_verify_otp():
    data = request.get_json() or {}
    raw_phone = data.get("phone", "").strip()
    otp_code = data.get("otp_code", "").strip()
    if not raw_phone or not otp_code:
        return jsonify({"status": "error", "message": "Missing phone or otp_code"}), 400
    phone = normalize_phone(raw_phone)
    if phone not in PHONE_TO_USERNAME:
        return jsonify({"status": "error", "message": "Phone not recognized"}), 404
    entry = pending_otps.get(phone)
    if not entry:
        return jsonify({"status": "fail", "message": "No OTP pending"}), 401
    if datetime.utcnow() > entry["expires"]:
        del pending_otps[phone]
        return jsonify({"status": "fail", "message": "OTP expired"}), 401
    if otp_code != entry["code"]:
        return jsonify({"status": "fail", "message": "Incorrect code"}), 401
    username = PHONE_TO_USERNAME[phone]
    session['username'] = username
    del pending_otps[phone]
    return jsonify({"status": "ok", "username": username}), 200

@app.route('/api/tasks', methods=['GET'])
def api_get_tasks():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()
    log(f"[api/tasks] Found {len(rows)} tasks")
    tasks_list = []
    for row in rows:
        tasks_list.append({
            "id": row["id"],
            "title": row["title"],
            "assigned_to": row["assigned_to"],
            "creation_date": row["creation_date"],
            "due_date": row["due_date"],
            "completed": row["completed"],
            "completed_by": row["completed_by"],
            "completed_on": row["completed_on"]
        })
    return jsonify(tasks_list), 200

@app.route('/api/tasks', methods=['POST'])
def api_create_task():
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "Title is required"}), 400
    title = data["title"]
    duration_hours = data.get("duration_hours", 48)
    assigned_to = data.get("assigned_to", None)
    creation_date = datetime.utcnow()
    due_date = creation_date + timedelta(hours=int(duration_hours))
    log(f"[api/create_task] Creating new task: title={title}, assigned_to={assigned_to}, due_in={duration_hours}h")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO tasks (title, assigned_to, creation_date, due_date)
        VALUES (?, ?, ?, ?)
    """, (title, assigned_to, creation_date.isoformat(), due_date.isoformat()))
    conn.commit()
    new_id = cursor.lastrowid
    cursor.execute("SELECT * FROM tasks WHERE id=?", (new_id,))
    row = cursor.fetchone()
    conn.close()
    created_task = {
        "id": row["id"],
        "title": row["title"],
        "assigned_to": row["assigned_to"],
        "creation_date": row["creation_date"],
        "due_date": row["due_date"],
        "completed": row["completed"],
        "completed_by": row["completed_by"],
        "completed_on": row["completed_on"]
    }
    log(f"[api/create_task] Task created with id={new_id}")
    if assigned_to:
        send_push_notification_to_user(
            assigned_to,
            f"Neue Aufgabe: {title}",
            f"Fällig bis {due_date.isoformat()}"
        )
        schedule_reminders(title, assigned_to, creation_date, due_date)
    return jsonify(created_task), 201

@app.route('/api/tasks/<int:task_id>/finish', methods=['POST'])
def api_finish_task(task_id):
    data = request.get_json(silent=True) or {}
    finisher = data.get("username", "Unknown")
    now = datetime.utcnow()
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE tasks
        SET completed=1, completed_by=?, completed_on=?
        WHERE id=?
    """, (finisher, now.isoformat(), task_id))
    conn.commit()
    cursor.execute("SELECT * FROM tasks WHERE id=?", (task_id,))
    row = cursor.fetchone()
    conn.close()
    if row is None:
        return jsonify({"error": "Task not found"}), 404
    updated_task = {
        "id": row["id"],
        "title": row["title"],
        "assigned_to": row["assigned_to"],
        "creation_date": row["creation_date"],
        "due_date": row["due_date"],
        "completed": row["completed"],
        "completed_by": row["completed_by"],
        "completed_on": row["completed_on"]
    }
    log(f"[api/finish_task] Task {task_id} completed successfully by {finisher}")
    send_push_notification_to_all(
        "Aufgabe erledigt",
        f"'{row['title']}' abgeschlossen von {finisher} am {now.isoformat()}"
    )
    return jsonify(updated_task), 200

@app.route('/api/stats', methods=['GET'])
def api_stats():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT completed_by, COUNT(*) as total_completed
        FROM tasks
        WHERE completed=1
        GROUP BY completed_by
    """)
    completions_rows = cursor.fetchall()
    completions_list = []
    for row in completions_rows:
        completed_by = row["completed_by"] if row["completed_by"] else ""
        completions_list.append({
            "completed_by": completed_by,
            "total_completed": row["total_completed"]
        })
    cursor.execute("SELECT * FROM tasks ORDER BY creation_date ASC")
    all_rows = cursor.fetchall()
    conn.close()
    all_tasks_list = []
    for r in all_rows:
        all_tasks_list.append({
            "id": r["id"],
            "title": r["title"],
            "assigned_to": r["assigned_to"],
            "creation_date": r["creation_date"],
            "due_date": r["due_date"],
            "completed": r["completed"],
            "completed_by": r["completed_by"],
            "completed_on": r["completed_on"]
        })
    result = {
        "completions": completions_list,
        "all_tasks": all_tasks_list
    }
    return jsonify(result), 200

# Endpoint to register device token for push notifications
@app.route('/api/register_token', methods=['POST'])
def register_token():
    """
    Expects JSON: { "token": "...", "username": "..." }
    Stores or updates the device token for the user.
    """
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

def schedule_reminders(task_title, assigned_user, creation_date, due_date):
    """
    Schedules reminders at 24h, 12h, 6h, 3h, 2h, and 1h before due_date.
    In production, store these in a database and process with a background job.
    Here we simply log the scheduled times.
    """
    intervals = [24, 12, 6, 3, 2, 1]  # in hours
    for h in intervals:
        remind_time = due_date - timedelta(hours=h)
        log(f"[schedule_reminders] Scheduled reminder for task '{task_title}' for user {assigned_user} at {remind_time.isoformat()}")

def send_push_notification_to_user(username, title, body):
    """
    Looks up device tokens for the given username and sends an FCM push notification.
    Uses the Firebase Admin SDK.
    """
    if not username:
        return
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT token FROM device_tokens WHERE username=?", (username,))
    tokens = [row["token"] for row in cursor.fetchall()]
    conn.close()
    log(f"[send_push_notification_to_user] Found {len(tokens)} token(s) for user {username}")
    for t in tokens:
        _send_fcm_push(t, title, body)

def send_push_notification_to_all(title, body):
    """
    Sends an FCM push notification to all stored device tokens.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT token FROM device_tokens")
    tokens = [row["token"] for row in cursor.fetchall()]
    conn.close()
    log(f"[send_push_notification_to_all] Found {len(tokens)} total token(s)")
    for t in tokens:
        _send_fcm_push(t, title, body)

def _send_fcm_push(token, title, body):
    """
    Sends a push notification using the Firebase Admin SDK.
    """
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
            data={
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "extra": "some_data_here"
            },
        )
        response = messaging.send(message)
        log(f"[_send_fcm_push] Successfully sent message: {response}")
    except Exception as e:
        log(f"[_send_fcm_push] Error sending message: {e}")

init_db()

if __name__ == '__main__':
    log("Starting Flask server on port 5444...")
    app.run(debug=True, port=5444)
