# models.py, do not remove this line

import datetime
import logging
from flask_sqlalchemy import SQLAlchemy

logging.debug("models.py loaded: Creating SQLAlchemy instance...")

db = SQLAlchemy()

logging.debug("models.py: Declaring models...")

class User(db.Model):
    __tablename__ = "user"
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    # Password hash is now optional because we're removing password-based login
    password_hash = db.Column(db.String(128), nullable=True)
    email = db.Column(db.String(120), unique=True, nullable=False)

    # We'll store the raw phone plus a canonical phone
    phone = db.Column(db.String(40), nullable=False)
    phone_canonical = db.Column(db.String(40), nullable=True, unique=False)

    phone_verified = db.Column(db.Boolean, default=False)
    email_verified = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)

class Item(db.Model):
    __tablename__ = "item"
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text, nullable=True)
    owner_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)

class ItemImage(db.Model):
    __tablename__ = "item_image"
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(200), nullable=False)
    item_id = db.Column(db.Integer, db.ForeignKey("item.id"), nullable=False)

class AuditLog(db.Model):
    __tablename__ = "audit_log"
    id = db.Column(db.Integer, primary_key=True)
    event_type = db.Column(db.String(50), nullable=False)  # 'login', 'register', 'google_login', etc.
    username = db.Column(db.String(80), nullable=False)
    success = db.Column(db.Boolean, default=False)
    details = db.Column(db.Text, nullable=True)  # Extra info
    timestamp = db.Column(db.DateTime, default=datetime.datetime.utcnow)

logging.debug("models.py: Done declaring models.")
