# app.py, do not remove this line

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
from datetime import datetime, timedelta

# 1) Import and enable CORS
from flask_cors import CORS

# NEW: Import Twilio client
from twilio.rest import Client

app = Flask(__name__)
app.secret_key = "yoursecretkey"  # Replace with a strong secret key

# Enable CORS for all routes:
CORS(app)

DATABASE = 'database.db'

#################### TWILIO CONFIGURATION ####################
# Replace these with your actual Twilio credentials / phone
TWILIO_ACCOUNT_SID = "YOUR_TWILIO_ACCOUNT_SID"
TWILIO_AUTH_TOKEN = "YOUR_TWILIO_AUTH_TOKEN"
TWILIO_FROM_NUMBER = "+1234567890"  # Your Twilio phone number
# Example phone numbers for each user (for demonstration)
USER_PHONE_NUMBERS = {
    "weasel": "+1987654321",
    "Otter": "+1987000111",
    # Add more if needed
}

def send_sms_on_login(username):
    """
    Sends an SMS to the user’s phone number when they have
    successfully logged in. This is a simple example that
    looks up the user’s phone from the USER_PHONE_NUMBERS dict.
    """
    # If user has no phone in the dict, skip sending
    if username not in USER_PHONE_NUMBERS:
        log(f"No phone number found for user={username}; skipping SMS.")
        return

    to_phone = USER_PHONE_NUMBERS[username]
    body_text = f"Hello {username}, you have just logged in!"

    try:
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        message = client.messages.create(
            body=body_text,
            from_=TWILIO_FROM_NUMBER,
            to=to_phone
        )
        log(f"Sent Twilio SMS to {username}: SID={message.sid}")
    except Exception as e:
        log(f"Error sending SMS via Twilio: {e}")
##############################################################

def get_db_connection():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

# ------------------ DEBUG HELPERS ------------------
def log(msg):
    """Simple helper to print debug messages with a prefix."""
    print(f"[DEBUG] {msg}")


# -- JINJA FILTERS --

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
    Initializes the database and inserts default data if empty.
    """
    log("Initializing database...")
    conn = get_db_connection()
    cursor = conn.cursor()

    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT
        )
    ''')

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

    # Create default users if they don't exist
    cursor.execute('SELECT COUNT(*) as count FROM users')
    count_users = cursor.fetchone()['count']
    if count_users == 0:
        log("No users found; inserting default users: weasel/123, Otter/1234.")
        cursor.execute(
            "INSERT INTO users (username, password) VALUES (?,?)",
            ("weasel", "123")
        )
        cursor.execute(
            "INSERT INTO users (username, password) VALUES (?,?)",
            ("Otter", "1234")
        )
        conn.commit()

    # Create default tasks if they don't exist
    cursor.execute('SELECT COUNT(*) as count FROM tasks')
    count_tasks = cursor.fetchone()['count']
    if count_tasks == 0:
        log("No tasks found; inserting default tasks Wäsche, Küche, kochen.")
        now_str = datetime.utcnow().isoformat()
        # We'll store times in UTC to keep it consistent
        cursor.execute("""INSERT INTO tasks (title, creation_date)
                          VALUES (?, ?)""", ("Wäsche", now_str))
        cursor.execute("""INSERT INTO tasks (title, creation_date)
                          VALUES (?, ?)""", ("Küche", now_str))
        cursor.execute("""INSERT INTO tasks (title, creation_date)
                          VALUES (?, ?)""", ("kochen", now_str))
        conn.commit()

    conn.close()
    log("Database init complete.")


@app.route('/')
def index():
    if 'username' in session:
        log(f"Index called; user '{session['username']}' is already logged in.")
        return redirect(url_for('dashboard'))
    log("Index called; no user in session, showing login page.")
    return render_template('index.html')


@app.route('/login', methods=['POST'])
def login():
    """
    Web-based login from an HTML form (index.html).
    Not used by the Flutter app (which calls /api/login).
    """
    log("Web-based /login called (HTML form).")
    username = request.form.get('username')
    password = request.form.get('password')
    log(f"Username={username}, Password={password}")

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT * FROM users WHERE username=? AND password=?",
        (username, password)
    )
    user = cursor.fetchone()
    conn.close()

    if user:
        log("Web-based login success. Storing session.")
        session['username'] = username
        # Send Twilio SMS after successful login
        send_sms_on_login(username)

        return redirect(url_for('dashboard'))
    else:
        log("Web-based login failed. Returning error page.")
        return render_template('index.html', error="Invalid credentials")


@app.route('/logout')
def logout():
    log(f"Logout called; clearing session.")
    session.clear()
    return redirect(url_for('index'))


@app.route('/dashboard')
def dashboard():
    if 'username' not in session:
        log("Dashboard called, but no user in session. Redirecting to index.")
        return redirect(url_for('index'))

    log("Dashboard called; fetching tasks.")
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
        log("create_task called, but no user in session. Redirecting.")
        return redirect(url_for('index'))

    title = request.form.get('title')
    duration_hours = request.form.get('duration', 48)
    assigned_to = request.form.get('assigned_to', None)
    log(f"Creating task title={title}, duration_hours={duration_hours}, assigned_to={assigned_to}.")

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

    log("Task created successfully (web-based). Redirecting to dashboard.")
    return redirect(url_for('dashboard'))


@app.route('/finish_task/<int:task_id>', methods=['POST'])
def finish_task(task_id):
    if 'username' not in session:
        log(f"finish_task called, but no user in session. Redirecting.")
        return redirect(url_for('index'))

    finisher = session['username']
    now = datetime.utcnow()
    log(f"Finishing task id={task_id}, completed_by={finisher}.")

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE tasks
        SET completed=1, completed_by=?, completed_on=?
        WHERE id=?
    """, (finisher, now.isoformat(), task_id))
    conn.commit()
    conn.close()

    log("Task marked as completed. Redirecting to dashboard.")
    return redirect(url_for('dashboard'))


@app.route('/stats')
def stats():
    """
    This is the HTML route that renders a Jinja2 template for /stats.
    The Flutter app does not use this route; it uses /api/stats.
    """
    if 'username' not in session:
        log("stats called, but no user in session. Redirecting.")
        return redirect(url_for('index'))

    log("Stats called; fetching completions + all tasks (HTML).")
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT completed_by, COUNT(*) as total_completed
        FROM tasks
        WHERE completed=1
        GROUP BY completed_by
    """)
    completions = cursor.fetchall()

    cursor.execute("""
        SELECT * FROM tasks
        ORDER BY creation_date ASC
    """)
    all_tasks = cursor.fetchall()

    conn.close()
    return render_template('stats.html', completions=completions, all_tasks=all_tasks)


@app.route('/export_csv')
def export_csv():
    log("export_csv called; exporting tasks as CSV.")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()

    si = io.StringIO()
    cw = csv.writer(si)
    cw.writerow([
        "id", "title", "assigned_to", "creation_date",
        "due_date", "completed", "completed_by", "completed_on"
    ])
    for row in rows:
        cw.writerow(list(row))

    output = make_csv_response(si.getvalue(), "tasks.csv")
    return output


@app.route('/export_xlsx')
def export_xlsx():
    log("export_xlsx called; exporting tasks as 'fake' XLSX CSV.")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()

    si = io.StringIO()
    cw = csv.writer(si)
    cw.writerow([
        "id", "title", "assigned_to", "creation_date",
        "due_date", "completed", "completed_by", "completed_on"
    ])
    for row in rows:
        cw.writerow(list(row))

    output = make_csv_response(si.getvalue(), "tasks.xlsx")
    return output


def make_csv_response(csv_string, filename):
    output = io.BytesIO()
    output.write(csv_string.encode('utf-8'))
    output.seek(0)
    return send_file(
        output,
        mimetype="text/csv",
        as_attachment=True,
        download_name=filename
    )


# -------------- NEW: FLUTTER/WEB API ENDPOINTS ---------------

@app.route('/api/heartbeat', methods=['GET'])
def api_heartbeat():
    """
    Simple heartbeat check:
    Returns { "status": "ok" }
    """
    log("API GET /api/heartbeat called. Returning {status: ok}.")
    return jsonify({"status": "ok"}), 200


@app.route('/api/login', methods=['POST'])
def api_login():
    """
    JSON-based login for Flutter.
    Expects:
      { "username": "...", "password": "..." }
    Returns 200 with {"status": "ok"} if valid,
    401 if invalid, or 400 if missing data.
    """
    log("API /api/login called.")
    data = request.get_json()
    log(f"  Received data: {data}")
    if not data or "username" not in data or "password" not in data:
        log("  Missing credentials in JSON.")
        return jsonify({"status": "error", "message": "Missing credentials"}), 400

    username = data["username"]
    password = data["password"]
    log(f"  Attempting login with username={username}")

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE username=? AND password=?", (username, password))
    user = cursor.fetchone()
    conn.close()

    if user:
        log("  Login successful!")
        # Send Twilio SMS after successful login
        send_sms_on_login(username)

        return jsonify({"status": "ok", "message": "Login successful"}), 200
    else:
        log("  Invalid credentials. Returning 401.")
        return jsonify({"status": "fail", "message": "Invalid credentials"}), 401


@app.route('/api/tasks', methods=['GET'])
def api_get_tasks():
    log("API GET /api/tasks called.")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()
    log(f"  Found {len(rows)} tasks total.")

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
    log("API POST /api/tasks called (create new task).")
    data = request.get_json()
    log(f"  Received data: {data}")
    if not data or "title" not in data:
        log("  Title is missing in JSON.")
        return jsonify({"error": "Title is required"}), 400

    title = data["title"]
    duration_hours = data.get("duration_hours", 48)
    assigned_to = data.get("assigned_to", None)

    creation_date = datetime.utcnow()
    due_date = creation_date + timedelta(hours=int(duration_hours))
    log(f"  Creating new task: title={title}, assigned_to={assigned_to}, due_in={duration_hours}h.")

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
    log(f"  Task created with id={new_id}.")
    return jsonify(created_task), 201


@app.route('/api/tasks/<int:task_id>/finish', methods=['POST'])
def api_finish_task(task_id):
    log(f"API POST /api/tasks/{task_id}/finish called.")
    data = request.get_json(silent=True) or {}
    finisher = data.get("username", "Unknown")
    log(f"  Marking task as finished by {finisher}.")
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
        log("  Task not found!")
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
    log(f"  Task {task_id} completed successfully.")
    return jsonify(updated_task), 200


# --- NEW JSON STATS ENDPOINT FOR FLUTTER ---
@app.route('/api/stats', methods=['GET'])
def api_stats():
    """
    Returns JSON:
    {
      "completions": [
        { "completed_by": "Wiesel", "total_completed": 5 },
        ...
      ],
      "all_tasks": [
        { "id":1, "title":"...", "assigned_to":"...", etc. },
        ...
      ]
    }
    """
    log("API GET /api/stats called.")
    conn = get_db_connection()
    cursor = conn.cursor()

    # Query completions
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

    # Query all tasks
    cursor.execute("""
        SELECT *
        FROM tasks
        ORDER BY creation_date ASC
    """)
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


# Initialize DB once at startup
init_db()

if __name__ == '__main__':
    log("Starting Flask server on port 5444...")
    app.run(debug=True, port=5444)
