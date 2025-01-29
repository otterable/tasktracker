# app.py, do not remove this line

from flask import Flask, render_template, request, redirect, url_for, session, jsonify, send_file
import sqlite3
import csv
import io
from datetime import datetime, timedelta

app = Flask(__name__)
app.secret_key = "yoursecretkey"  # Replace with a strong secret key

DATABASE = 'database.db'

def get_db_connection():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

# -- JINJA FILTERS --

@app.template_filter("human_date")
def human_date(value):
    """
    Converts an ISO datetime string (e.g. '2025-01-29T17:57:21.818417') 
    to 'dd.mm.%Y, HH:MM'.
    """
    if not value:
        return ""
    dt = datetime.fromisoformat(value)
    return dt.strftime("%d.%m.%Y, %H:%M")

@app.template_filter("time_taken")
def time_taken(created_str, completed_str):
    """
    Returns how long it took from creation to completion in days/hours/minutes,
    e.g., "1d 3h 15m".
    """
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
    """
    Converts a string in ISO format to a Python datetime object.
    """
    if not value:
        return None
    return datetime.fromisoformat(value)

# Initialize the database if necessary
def init_db():
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
        # Insert Wiesel and Otter
        cursor.execute("INSERT INTO users (username, password) VALUES (?,?)", ("Wiesel", "1234"))
        cursor.execute("INSERT INTO users (username, password) VALUES (?,?)", ("Otter", "1234"))
        conn.commit()

    # Create default tasks if they don't exist
    cursor.execute('SELECT COUNT(*) as count FROM tasks')
    count_tasks = cursor.fetchone()['count']
    if count_tasks == 0:
        # Insert the three default tasks
        now_str = datetime.utcnow().isoformat()
        # We'll store all times in UTC (you can adjust with +1 hour if you want local time).
        cursor.execute("""INSERT INTO tasks (title, creation_date) 
                          VALUES (?, ?)""", ("Wäsche", now_str))
        cursor.execute("""INSERT INTO tasks (title, creation_date) 
                          VALUES (?, ?)""", ("Küche", now_str))
        cursor.execute("""INSERT INTO tasks (title, creation_date) 
                          VALUES (?, ?)""", ("kochen", now_str))
        conn.commit()

    conn.close()

@app.before_first_request
def setup():
    init_db()

@app.route('/')
def index():
    """
    If user is logged in, go to dashboard.
    Otherwise, go to login page.
    """
    if 'username' in session:
        return redirect(url_for('dashboard'))
    return render_template('index.html')

@app.route('/login', methods=['POST'])
def login():
    username = request.form.get('username')
    password = request.form.get('password')

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE username=? AND password=?", (username, password))
    user = cursor.fetchone()
    conn.close()

    if user:
        session['username'] = username
        return redirect(url_for('dashboard'))
    else:
        return render_template('index.html', error="Invalid credentials")

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

@app.route('/dashboard')
def dashboard():
    """
    Main screen with the calendar-like task overview, 
    the creation form, and the list of tasks.
    """
    if 'username' not in session:
        return redirect(url_for('index'))

    # Retrieve tasks
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks WHERE completed=0")
    open_tasks = cursor.fetchall()
    cursor.execute("SELECT * FROM tasks WHERE completed=1")
    completed_tasks = cursor.fetchall()
    conn.close()

    # Build a list of the next 7 days for the calendar
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

    title = request.form.get('title')  # e.g. Wäsche, Küche, kochen or custom
    duration_hours = request.form.get('duration', 48)  # default 48
    assigned_to = request.form.get('assigned_to', None)  # Wiesel, Otter, or None

    # Store creation time in UTC by default
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

    # In a real environment, you'd trigger a push notification to the assigned user
    # but we'll skip that here and rely on the client to handle new tasks.
    return redirect(url_for('dashboard'))

@app.route('/finish_task/<int:task_id>', methods=['POST'])
def finish_task(task_id):
    if 'username' not in session:
        return redirect(url_for('index'))

    finisher = session['username']
    now = datetime.utcnow()

    conn = get_db_connection()
    cursor = conn.cursor()
    # Mark as completed
    cursor.execute("""
        UPDATE tasks
        SET completed=1, completed_by=?, completed_on=?
        WHERE id=?
    """, (finisher, now.isoformat(), task_id))
    conn.commit()
    conn.close()

    return redirect(url_for('dashboard'))

@app.route('/stats')
def stats():
    """
    Show stats on how many tasks each user has completed,
    and offer CSV/Excel export.
    """
    if 'username' not in session:
        return redirect(url_for('index'))

    conn = get_db_connection()
    cursor = conn.cursor()

    # Completed tasks count per user
    cursor.execute("""
        SELECT completed_by, COUNT(*) as total_completed
        FROM tasks
        WHERE completed=1
        GROUP BY completed_by
    """)
    completions = cursor.fetchall()

    # Full task history
    cursor.execute("""
        SELECT * FROM tasks
        ORDER BY creation_date ASC
    """)
    all_tasks = cursor.fetchall()

    conn.close()

    return render_template('stats.html', completions=completions, all_tasks=all_tasks)

@app.route('/export_csv')
def export_csv():
    """
    Exports all tasks into CSV format.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()

    si = io.StringIO()
    cw = csv.writer(si)
    # Write headers
    cw.writerow(["id", "title", "assigned_to", "creation_date", "due_date", 
                 "completed", "completed_by", "completed_on"])
    for row in rows:
        cw.writerow(list(row))

    output = make_csv_response(si.getvalue(), "tasks.csv")
    return output

@app.route('/export_xlsx')
def export_xlsx():
    """
    Minimal example: 'fake' XLSX export by sending CSV with .xlsx extension.
    For real Excel, use xlsxwriter or openpyxl to generate .xlsx directly.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM tasks")
    rows = cursor.fetchall()
    conn.close()

    si = io.StringIO()
    cw = csv.writer(si)
    # Write headers
    cw.writerow(["id", "title", "assigned_to", "creation_date", "due_date", 
                 "completed", "completed_by", "completed_on"])
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

if __name__ == '__main__':
    app.run(debug=True)
