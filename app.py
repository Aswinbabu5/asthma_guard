import pandas as pd
import numpy as np
import joblib
import sqlite3
import bcrypt
import jwt as pyjwt
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from flask_cors import CORS
from datetime import datetime, timedelta, timezone
from collections import deque
from functools import wraps
from threading import Lock
import os
import logging
from twilio.rest import Client as TwilioClient
from twilio.base.exceptions import TwilioRestException

# ════════════════════════════════════════════════════════════════
#  APP + LOGGING
# ════════════════════════════════════════════════════════════════
app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger(__name__)

# ════════════════════════════════════════════════════════════════
#  CONFIG
# ════════════════════════════════════════════════════════════════
app.secret_key = os.environ.get('SECRET_KEY', 'dev_only_secret_change_in_production')
if app.secret_key == 'dev_only_secret_change_in_production':
    log.warning("SECRET_KEY not set in environment — using insecure dev default")

JWT_SECRET = os.environ.get('JWT_SECRET', 'dev_only_jwt_secret_change_in_production')
if JWT_SECRET == 'dev_only_jwt_secret_change_in_production':
    log.warning("JWT_SECRET not set in environment — using insecure dev default")

JWT_EXPIRY = timedelta(days=30)

MODEL_PATH = os.environ.get(
    'MODEL_PATH',
    '/home/a4pi/Documents/main_project/smart_iot_asthma_aqi_pipeline.joblib'
)

_raw_origins = os.environ.get('ALLOWED_ORIGINS', '*')
ALLOWED_ORIGINS = [o.strip() for o in _raw_origins.split(',')] if _raw_origins != '*' else '*'
CORS(app, origins=ALLOWED_ORIGINS, supports_credentials=True)

# ════════════════════════════════════════════════════════════════
#  ESP32 DEVICE CREDENTIALS
#  Must match DEV_USER / DEV_PASS in your Arduino sketch
# ════════════════════════════════════════════════════════════════
ESP32_USERNAME = 'akashanand'
ESP32_PASSWORD = 'anand28122004'

# ════════════════════════════════════════════════════════════════
#  JWT HELPERS
# ════════════════════════════════════════════════════════════════
def make_token(user_id: int, username: str, name: str) -> str:
    payload = {
        'user_id':  user_id,
        'username': username,
        'name':     name,
        'exp':      datetime.now(timezone.utc) + JWT_EXPIRY,
        'iat':      datetime.now(timezone.utc),
    }
    return pyjwt.encode(payload, JWT_SECRET, algorithm='HS256')

def decode_token(token: str):
    try:
        return pyjwt.decode(token, JWT_SECRET, algorithms=['HS256'])
    except pyjwt.ExpiredSignatureError:
        log.debug("JWT expired")
        return None
    except pyjwt.InvalidTokenError as e:
        log.debug(f"JWT invalid: {e}")
        return None

def get_token_from_request():
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        return decode_token(auth[7:])
    return None

def get_current_user():
    """Returns user payload from JWT or session, whichever is present."""
    payload = get_token_from_request()
    if payload:
        return payload
    if 'user_id' in session:
        return {
            'user_id':  session['user_id'],
            'username': session['username'],
            'name':     session['name']
        }
    return None

# ════════════════════════════════════════════════════════════════
#  DATABASE
# ════════════════════════════════════════════════════════════════
DB = os.environ.get('DB_PATH', 'asthma_guard.db')

def get_db():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn

def init_db():
    with get_db() as db:
        db.executescript('''
            CREATE TABLE IF NOT EXISTS users (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                name      TEXT    NOT NULL,
                username  TEXT    NOT NULL UNIQUE,
                password  TEXT    NOT NULL,
                created   TEXT    DEFAULT (datetime('now'))
            );
            CREATE TABLE IF NOT EXISTS readings (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id    INTEGER NOT NULL,
                pm25       REAL, pm10 REAL, no2 REAL, so2 REAL,
                co         REAL, o3  REAL, temp REAL, humidity REAL,
                spo2       REAL, heart_rate REAL,
                aqi        INTEGER, risk TEXT,
                recorded   TEXT DEFAULT (datetime('now')),
                FOREIGN KEY(user_id) REFERENCES users(id)
            );
            CREATE INDEX IF NOT EXISTS idx_readings_user_recorded
                ON readings(user_id, recorded DESC);
            CREATE TABLE IF NOT EXISTS sms_alerts (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id     INTEGER,
                alert_type  TEXT NOT NULL,
                message     TEXT NOT NULL,
                recipient   TEXT NOT NULL,
                twilio_sid  TEXT,
                sent_at     TEXT DEFAULT (datetime('now')),
                FOREIGN KEY(user_id) REFERENCES users(id)
            );
        ''')
    log.info(f"Database ready → {DB}")

# ── Password hashing ─────────────────────────────────────────────
def hash_pw(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def check_pw(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode(), hashed.encode())
    except Exception:
        return False

init_db()

# ── Auto-register ESP32 device user if not exists ────────────────
def ensure_esp32_user():
    """
    Creates the ESP32 device user account in DB on first run
    so the Arduino sketch can login immediately without manual setup.
    """
    with get_db() as db:
        existing = db.execute(
            'SELECT id FROM users WHERE username=?', (ESP32_USERNAME,)
        ).fetchone()
        if not existing:
            db.execute(
                'INSERT INTO users (name, username, password) VALUES (?, ?, ?)',
                ('ESP32 Device', ESP32_USERNAME, hash_pw(ESP32_PASSWORD))
            )
            log.info(f"ESP32 device user '{ESP32_USERNAME}' auto-created in DB")
        else:
            log.info(f"ESP32 device user '{ESP32_USERNAME}' already exists")

ensure_esp32_user()

# ════════════════════════════════════════════════════════════════
#  AUTH DECORATORS
# ════════════════════════════════════════════════════════════════
def login_required(f):
    """Browser routes — uses session cookie."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login_page'))
        return f(*args, **kwargs)
    return decorated

def api_login_required(f):
    """API routes — accepts JWT Bearer OR session (covers ESP32 + Flutter + browser)."""
    @wraps(f)
    def decorated(*args, **kwargs):
        user = get_current_user()
        if not user:
            return jsonify({'success': False, 'message': 'Unauthorized'}), 401
        request.current_user = user
        return f(*args, **kwargs)
    return decorated

# ════════════════════════════════════════════════════════════════
#  ML MODEL
# ════════════════════════════════════════════════════════════════
try:
    model = joblib.load(MODEL_PATH)
    log.info(f"Model loaded from {MODEL_PATH}")
except Exception as e:
    log.warning(f"Model not loaded ({MODEL_PATH}): {e} — falling back to AQI category")
    model = None

# ════════════════════════════════════════════════════════════════
#  ROLLING HISTORY  (thread-safe)
# ════════════════════════════════════════════════════════════════
HISTORY_SIZE  = 6
_history_lock = Lock()
pm25_history  = deque([0.0] * HISTORY_SIZE, maxlen=HISTORY_SIZE)
pm10_history  = deque([0.0] * HISTORY_SIZE, maxlen=HISTORY_SIZE)

_status_lock   = Lock()
current_status = {
    "pm25": 0, "pm10": 0, "no2": 0, "so2": 0, "co": 0, "o3": 0,
    "temp": 0, "humidity": 0, "spo2": 0, "heart_rate": 0,
    "spo2_alert": False, "hr_alert": False,
    "risk": "Waiting for data...", "aqi": 0, "aqi_cat": "",
    "timestamp": "--:--"
}

# ════════════════════════════════════════════════════════════════
#  TWILIO SMS ALERTS
# ════════════════════════════════════════════════════════════════
_TWILIO_SID    = os.environ.get('TWILIO_ACCOUNT_SID')
_TWILIO_TOKEN  = os.environ.get('TWILIO_AUTH_TOKEN')
_TWILIO_FROM   = os.environ.get('TWILIO_FROM')
_PATIENT_PHONE = os.environ.get('PATIENT_PHONE')

_twilio_client = None
if _TWILIO_SID and _TWILIO_TOKEN:
    _twilio_client = TwilioClient(_TWILIO_SID, _TWILIO_TOKEN)
    log.info("Twilio client initialised")
else:
    log.warning("Twilio credentials not set — SMS alerts disabled")

_SMS_COOLDOWN_SECONDS    = 300
_sms_last_sent: dict     = {}
_sms_lock                = Lock()

def _cooldown_ok(alert_key: str) -> bool:
    with _sms_lock:
        last = _sms_last_sent.get(alert_key)
        if last and (datetime.now() - last).total_seconds() < _SMS_COOLDOWN_SECONDS:
            return False
        _sms_last_sent[alert_key] = datetime.now()
        return True

def send_alert_sms(alert_type: str, message: str,
                   to: str = None, user_id: int = None) -> bool:
    if not _twilio_client:
        log.warning(f"SMS skipped (no Twilio client) — alert_type={alert_type}")
        return False

    recipient = to or _PATIENT_PHONE
    if not recipient:
        log.warning("SMS skipped — PATIENT_PHONE not set")
        return False

    if not _cooldown_ok(alert_type):
        log.info(f"SMS suppressed by cooldown — alert_type={alert_type}")
        return False

    twilio_sid = None
    try:
        msg = _twilio_client.messages.create(
            body=message, from_=_TWILIO_FROM, to=recipient
        )
        twilio_sid = msg.sid
        log.info(f"SMS sent → {recipient} | SID={twilio_sid} | type={alert_type}")
        success = True
    except TwilioRestException as e:
        log.error(f"Twilio error [{alert_type}]: {e}")
        success = False

    try:
        with get_db() as db:
            db.execute(
                '''INSERT INTO sms_alerts
                   (user_id, alert_type, message, recipient, twilio_sid)
                   VALUES (?, ?, ?, ?, ?)''',
                (user_id, alert_type, message, recipient, twilio_sid)
            )
    except Exception as e:
        log.error(f"Failed to log SMS alert to DB: {e}")

    return success


def check_and_alert(spo2: float, heart_rate: float, aqi_value: int,
                    aqi_cat: str, timestamp: str,
                    user_id: int = None) -> list:
    triggered = []

    if spo2 > 0 and spo2 < 94:
        severity = "CRITICAL" if spo2 < 90 else "WARNING"
        msg = (
            f"[AsthmaGuard {severity}] PULMONARY ALERT\n"
            f"SpO2 dropped to {spo2:.1f}% at {timestamp}.\n"
            f"Normal range: 94-100%. Please seek medical attention immediately."
        )
        if send_alert_sms('pulmonary', msg, user_id=user_id):
            triggered.append('pulmonary')

    if heart_rate > 0 and heart_rate < 50:
        msg = (
            f"[AsthmaGuard WARNING] CARDIAC ALERT - Low Heart Rate\n"
            f"Heart rate is {heart_rate:.0f} bpm at {timestamp}.\n"
            f"Normal range: 60-100 bpm. Please check on the patient."
        )
        if send_alert_sms('cardiac_low', msg, user_id=user_id):
            triggered.append('cardiac_low')

    if heart_rate > 110:
        msg = (
            f"[AsthmaGuard WARNING] CARDIAC ALERT - High Heart Rate\n"
            f"Heart rate is {heart_rate:.0f} bpm at {timestamp}.\n"
            f"Normal range: 60-100 bpm. Please check on the patient."
        )
        if send_alert_sms('cardiac_high', msg, user_id=user_id):
            triggered.append('cardiac_high')

    if aqi_value > 150:
        msg = (
            f"[AsthmaGuard ALERT] POOR AIR QUALITY\n"
            f"AQI is {aqi_value} ({aqi_cat}) at {timestamp}.\n"
            f"Asthma risk is elevated. Patient should stay indoors and use inhaler if needed."
        )
        if send_alert_sms('aqi', msg, user_id=user_id):
            triggered.append('aqi')

    return triggered

# ════════════════════════════════════════════════════════════════
#  INPUT VALIDATION
# ════════════════════════════════════════════════════════════════
SENSOR_RANGES = {
    'pm25':       (0,   999),
    'pm10':       (0,   999),
    'no2':        (0,    10),
    'so2':        (0,    10),
    'co':         (0,   100),
    'o3':         (0,     1),
    'temp':       (-40,  80),
    'humidity':   (0,   100),
    'spo2':       (0,   100),
    'heart_rate': (0,   250),
}

def validate_sensor_data(data: dict):
    values = {}
    errors = []
    for field, (lo, hi) in SENSOR_RANGES.items():
        try:
            v = float(data.get(field, 0))
            if not (lo <= v <= hi):
                errors.append(f"{field}={v} out of range [{lo}, {hi}]")
            values[field] = v
        except (ValueError, TypeError):
            errors.append(f"{field} must be a number")
            values[field] = 0.0
    return values, errors

# ════════════════════════════════════════════════════════════════
#  EPA AQI CALCULATOR
# ════════════════════════════════════════════════════════════════
def calculate_aqi(pm25, pm10, no2, so2, co, o3):
    def linear(ahi, alo, bhi, blo, c):
        return round((ahi - alo) / (bhi - blo) * (c - blo) + alo)

    def sub25(c):
        c = round(c, 1)
        for lo, hi, al, ah in [
            (0, 12, 0, 50), (12.1, 35.4, 51, 100), (35.5, 55.4, 101, 150),
            (55.5, 150.4, 151, 200), (150.5, 250.4, 201, 300),
            (250.5, 350.4, 301, 400), (350.5, 500.4, 401, 500)
        ]:
            if lo <= c <= hi:
                return linear(ah, al, hi, lo, c)
        return 500

    def sub10(c):
        c = int(c)
        for lo, hi, al, ah in [
            (0, 54, 0, 50), (55, 154, 51, 100), (155, 254, 101, 150),
            (255, 354, 151, 200), (355, 424, 201, 300),
            (425, 504, 301, 400), (505, 604, 401, 500)
        ]:
            if lo <= c <= hi:
                return linear(ah, al, hi, lo, c)
        return 500

    def subno2(p):
        c = p * 1000
        for lo, hi, al, ah in [
            (0, 53, 0, 50), (54, 100, 51, 100), (101, 360, 101, 150),
            (361, 649, 151, 200), (650, 1249, 201, 300),
            (1250, 1649, 301, 400), (1650, 2049, 401, 500)
        ]:
            if lo <= c <= hi:
                return linear(ah, al, hi, lo, c)
        return 500

    def subo3(c):
        c = round(c, 3)
        for lo, hi, al, ah in [
            (0, 0.054, 0, 50), (0.055, 0.070, 51, 100),
            (0.071, 0.085, 101, 150), (0.086, 0.105, 151, 200),
            (0.106, 0.200, 201, 300)
        ]:
            if lo <= c <= hi:
                return linear(ah, al, hi, lo, c)
        return 300

    def subco(c):
        c = round(c, 1)
        for lo, hi, al, ah in [
            (0, 4.4, 0, 50), (4.5, 9.4, 51, 100), (9.5, 12.4, 101, 150),
            (12.5, 15.4, 151, 200), (15.5, 30.4, 201, 300),
            (30.5, 40.4, 301, 400), (40.5, 50.4, 401, 500)
        ]:
            if lo <= c <= hi:
                return linear(ah, al, hi, lo, c)
        return 500

    aqi = max(sub25(pm25), sub10(pm10), subno2(no2), subo3(o3), subco(co))
    if   aqi <= 50:  cat = "Good"
    elif aqi <= 100: cat = "Moderate"
    elif aqi <= 150: cat = "Unhealthy for Sensitive Groups"
    elif aqi <= 200: cat = "Unhealthy"
    elif aqi <= 300: cat = "Very Unhealthy"
    else:            cat = "Hazardous"
    return aqi, cat

# ════════════════════════════════════════════════════════════════
#  FEATURE ENGINEERING
# ════════════════════════════════════════════════════════════════
def build_features(pm25, pm10, no2, so2, co, o3, temp, humidity):
    now = datetime.now()
    hour, month = now.hour, now.month

    with _history_lock:
        pm25_history.append(pm25)
        pm10_history.append(pm10)
        h25 = list(pm25_history)
        h10 = list(pm10_history)

    return pd.DataFrame([{
        'pm2.5': pm25, 'pm10': pm10, 'no2': no2, 'so2': so2,
        'co': co, 'o3': o3, 'temp': temp, 'humidity': humidity,
        'pm2.5_lag1': h25[-2], 'pm2.5_lag3': h25[-4], 'pm2.5_lag6': h25[-6],
        'pm10_lag1':  h10[-2], 'pm10_lag3':  h10[-4],
        'pm25_roll3':  float(np.mean(h25[-3:])),
        'pm25_roll6':  float(np.mean(h25)),
        'pm2.5_humidity': pm25 * humidity, 'pm10_humidity': pm10 * humidity,
        'pm2.5_temp':     pm25 * temp,     'pm10_temp':     pm10 * temp,
        'asthma_trigger_index': pm25*0.5 + pm10*0.3 + no2*50 + so2*40 + o3*30,
        'hour_sin':  np.sin(2 * np.pi * hour  / 24),
        'hour_cos':  np.cos(2 * np.pi * hour  / 24),
        'month_sin': np.sin(2 * np.pi * month / 12),
        'month_cos': np.cos(2 * np.pi * month / 12),
        'latitude': 11.0168, 'longitude': 76.9558, 'city': 'Coimbatore',
    }])

# ════════════════════════════════════════════════════════════════
#  WEB ROUTES  (browser)
# ════════════════════════════════════════════════════════════════
@app.route('/login-page')
def login_page():
    if 'user_id' in session:
        return redirect(url_for('home'))
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login_page'))

@app.route('/')
@login_required
def home():
    return render_template('index.html')

@app.route('/test')
@login_required
def test_panel():
    return render_template('test_panel.html')

# ════════════════════════════════════════════════════════════════
#  API — AUTH
# ════════════════════════════════════════════════════════════════
@app.route('/login', methods=['POST'])
def login():
    data    = request.get_json(force=True, silent=True)
    is_json = data is not None

    if is_json:
        username = str(data.get('username', '')).strip().lower()
        password = str(data.get('password', ''))
    else:
        username = request.form.get('username', '').strip().lower()
        password = request.form.get('password', '')

    if not username or not password:
        if is_json:
            return jsonify({'success': False, 'message': 'Fill in all fields.'}), 400
        return redirect(url_for('login_page'))

    with get_db() as db:
        user = db.execute(
            'SELECT * FROM users WHERE username=?', (username,)
        ).fetchone()

    if not user or not check_pw(password, user['password']):
        if is_json:
            return jsonify({'success': False, 'message': 'Invalid username or password.'}), 401
        return redirect(url_for('login_page'))

    session['user_id']  = user['id']
    session['username'] = user['username']
    session['name']     = user['name']

    if is_json:
        token = make_token(user['id'], user['username'], user['name'])
        return jsonify({
            'success':  True,
            'token':    token,
            'name':     user['name'],
            'username': user['username']
        })

    return redirect(url_for('home'))


@app.route('/register', methods=['POST'])
def register():
    data    = request.get_json(force=True, silent=True)
    is_json = data is not None

    if is_json:
        name     = str(data.get('name',     '')).strip()
        username = str(data.get('username', '')).strip().lower()
        password = str(data.get('password', ''))
    else:
        name     = request.form.get('name',     '').strip()
        username = request.form.get('username', '').strip().lower()
        password = request.form.get('password', '')

    if not name or not username or not password:
        return jsonify({'success': False, 'message': 'Fill in all fields.'}), 400
    if len(password) < 8:
        return jsonify({'success': False, 'message': 'Password must be at least 8 characters.'}), 400
    if len(username) < 3:
        return jsonify({'success': False, 'message': 'Username must be at least 3 characters.'}), 400

    try:
        with get_db() as db:
            db.execute(
                'INSERT INTO users (name, username, password) VALUES (?, ?, ?)',
                (name, username, hash_pw(password))
            )
            user = db.execute(
                'SELECT * FROM users WHERE username=?', (username,)
            ).fetchone()

        session['user_id']  = user['id']
        session['username'] = user['username']
        session['name']     = user['name']

        if is_json:
            token = make_token(user['id'], user['username'], user['name'])
            return jsonify({
                'success':  True,
                'token':    token,
                'name':     user['name'],
                'username': user['username']
            }), 201
        return redirect(url_for('home'))

    except sqlite3.IntegrityError:
        return jsonify({'success': False, 'message': 'Username already taken.'}), 409

# ════════════════════════════════════════════════════════════════
#  API — SENSOR DATA
#  /update_sensor  — accepts BOTH authenticated (JWT) requests
#                    AND unauthenticated ESP32 requests.
#
#  If a valid JWT is present  → data is stored under that user.
#  If NO JWT is present        → data is stored under the ESP32
#                                device account (auto-created above).
# ════════════════════════════════════════════════════════════════
@app.route('/update_sensor', methods=['POST'])
def update_sensor():
    global current_status

    raw = request.get_json(force=True, silent=True)
    if not raw:
        return jsonify({'status': 'error', 'message': 'No JSON body'}), 400

    # ── Resolve user_id ─────────────────────────────────────────
    user = get_current_user()
    if user:
        user_id = user.get('user_id')
    else:
        # No JWT — treat as ESP32 device user
        with get_db() as db:
            esp_user = db.execute(
                'SELECT id FROM users WHERE username=?', (ESP32_USERNAME,)
            ).fetchone()
        user_id = esp_user['id'] if esp_user else None
        log.info(f"[update_sensor] No JWT — using ESP32 device user_id={user_id}")

    values, errors = validate_sensor_data(raw)
    if errors:
        log.warning(f"Sensor validation warnings: {errors}")

    pm25 = values['pm25'];  pm10 = values['pm10']
    no2  = values['no2'];   so2  = values['so2']
    co   = values['co'];    o3   = values['o3']
    temp = values['temp'];  humidity   = values['humidity']
    spo2 = values['spo2'];  heart_rate = values['heart_rate']

    spo2_alert = spo2 > 0 and spo2 < 94
    hr_alert   = heart_rate > 0 and (heart_rate < 50 or heart_rate > 110)
    aqi_value, aqi_cat = calculate_aqi(pm25, pm10, no2, so2, co, o3)

    # ── ML risk prediction ───────────────────────────────────────
    risk_override = raw.get('risk_override')
    if risk_override:
        predicted_risk = str(risk_override)
    elif model:
        try:
            raw_pred = model.predict(
                build_features(pm25, pm10, no2, so2, co, o3, temp, humidity)
            )[0]
            try:
                float(raw_pred)
                predicted_risk = aqi_cat
            except (ValueError, TypeError):
                predicted_risk = str(raw_pred)
        except Exception as e:
            log.error(f"Model prediction error: {e}")
            predicted_risk = aqi_cat
    else:
        predicted_risk = aqi_cat

    new_status = {
        "pm25": pm25, "pm10": pm10, "no2": no2, "so2": so2,
        "co": co, "o3": o3, "temp": temp, "humidity": humidity,
        "spo2": spo2, "heart_rate": heart_rate,
        "spo2_alert": spo2_alert, "hr_alert": hr_alert,
        "risk": predicted_risk, "aqi": aqi_value, "aqi_cat": aqi_cat,
        "timestamp": datetime.now().strftime("%H:%M:%S")
    }

    with _status_lock:
        current_status = new_status

    # ── Save to DB ───────────────────────────────────────────────
    try:
        with get_db() as db:
            db.execute(
                '''INSERT INTO readings
                   (user_id, pm25, pm10, no2, so2, co, o3, temp, humidity,
                    spo2, heart_rate, aqi, risk)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)''',
                (user_id, pm25, pm10, no2, so2, co, o3, temp, humidity,
                 spo2, heart_rate, aqi_value, predicted_risk)
            )
    except Exception as e:
        log.error(f"DB insert failed for user {user_id}: {e}")

    # ── SMS alerts ───────────────────────────────────────────────
    ts = new_status["timestamp"]
    alerts_fired = check_and_alert(
        spo2, heart_rate, aqi_value, aqi_cat, ts, user_id=user_id
    )

    return jsonify({
        'status':       'success',
        'risk':         predicted_risk,
        'aqi':          aqi_value,
        'aqi_cat':      aqi_cat,
        'spo2':         spo2,
        'heart_rate':   heart_rate,
        'spo2_alert':   spo2_alert,
        'hr_alert':     hr_alert,
        'warnings':     errors,
        'alerts_fired': alerts_fired,
    })


@app.route('/get_status')
@api_login_required
def get_status():
    """Returns the latest sensor snapshot."""
    with _status_lock:
        snapshot = dict(current_status)
    return jsonify(snapshot)


@app.route('/history')
@api_login_required
def history():
    """Returns last N readings for the authenticated user."""
    user_id = request.current_user.get('user_id')
    limit   = min(request.args.get('limit', 50, type=int), 500)

    with get_db() as db:
        rows = db.execute(
            'SELECT * FROM readings WHERE user_id=? ORDER BY recorded DESC LIMIT ?',
            (user_id, limit)
        ).fetchall()

    return jsonify([dict(r) for r in rows])


@app.route('/stats')
@api_login_required
def stats():
    """Returns 24-hour averages and peak values."""
    user_id = request.current_user.get('user_id')

    with get_db() as db:
        row = db.execute('''
            SELECT
                ROUND(AVG(pm25), 2)       AS avg_pm25,
                ROUND(AVG(pm10), 2)       AS avg_pm10,
                ROUND(AVG(co),   2)       AS avg_co,
                ROUND(AVG(aqi),  0)       AS avg_aqi,
                ROUND(MAX(aqi),  0)       AS peak_aqi,
                ROUND(MAX(pm25), 2)       AS peak_pm25,
                ROUND(AVG(spo2), 1)       AS avg_spo2,
                ROUND(AVG(heart_rate), 1) AS avg_hr,
                COUNT(*)                  AS total_readings
            FROM readings
            WHERE user_id = ?
              AND recorded >= datetime('now', '-24 hours')
        ''', (user_id,)).fetchone()

    return jsonify(dict(row) if row else {})


# ════════════════════════════════════════════════════════════════
#  API — SMS ALERT HISTORY
# ════════════════════════════════════════════════════════════════
@app.route('/alert_history')
@api_login_required
def alert_history():
    user_id = request.current_user.get('user_id')
    limit   = min(request.args.get('limit', 50, type=int), 200)

    with get_db() as db:
        rows = db.execute(
            '''SELECT alert_type, message, recipient, twilio_sid, sent_at
               FROM sms_alerts
               WHERE user_id=?
               ORDER BY sent_at DESC LIMIT ?''',
            (user_id, limit)
        ).fetchall()

    return jsonify([dict(r) for r in rows])


@app.route('/test_alert', methods=['POST'])
@api_login_required
def test_alert():
    """Manually trigger a test SMS to verify Twilio credentials."""
    import uuid
    user_id    = request.current_user.get('user_id')
    data       = request.get_json(force=True, silent=True) or {}
    alert_type = data.get('alert_type', 'test')
    ts         = datetime.now().strftime("%H:%M:%S")
    msg        = (
        f"[AsthmaGuard TEST] This is a test alert ({alert_type}) "
        f"sent at {ts}. Your Twilio integration is working correctly."
    )
    test_key = f"test_{uuid.uuid4().hex}"
    with _sms_lock:
        _sms_last_sent[test_key] = datetime.min

    success = send_alert_sms(test_key, msg, user_id=user_id)
    return jsonify({
	        'success': success,
        'message': 'Test SMS sent' if success else 'SMS failed — check logs'
    })


# ════════════════════════════════════════════════════════════════
#  HEALTH CHECK
# ════════════════════════════════════════════════════════════════
@app.route('/health')
def health():
    return jsonify({
        'status':    'ok',
        'timestamp': datetime.now(timezone.utc).isoformat()
    })


# ════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    port  = int(os.environ.get('PORT', 5000))
    log.info(f"Starting AsthmaGuard Flask server on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug, use_reloader=False)