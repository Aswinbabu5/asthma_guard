import sqlite3
import bcrypt

DB = 'asthma_guard.db'
conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row

# Show all users first
print("Users in database:")
users = conn.execute("SELECT id, username, name, password FROM users").fetchall()
for u in users:
    is_bcrypt = u['password'].startswith('$2b$') or u['password'].startswith('$2a$')
    print(f"  ID:{u['id']}  username:{u['username']}  "
          f"hash:{'bcrypt' if is_bcrypt else 'SHA256 (old — needs reset)'}")

print()
username     = input("Enter username to reset: ").strip().lower()
new_password = input("Enter new password (min 8 chars): ").strip()

if len(new_password) < 8:
    print("Password too short!")
else:
    new_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()
    conn.execute("UPDATE users SET password=? WHERE username=?", (new_hash, username))
    conn.commit()
    print(f"Password reset for '{username}'")

conn.close()