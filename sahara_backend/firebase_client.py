"""
SAHARA AI — Firebase Client
Firebase Realtime Database integration for persisting crisis records and logs.

NOTE: In-memory store used by default. To enable Firebase:
1. pip install firebase-admin
2. Add your Firebase service account key JSON
3. Set FIREBASE_ENABLED=true
"""

import os
import json
from datetime import datetime
from typing import Optional, Dict, Any, List

# ── Configuration ───────────────────────────
FIREBASE_ENABLED = os.getenv("FIREBASE_ENABLED", "false").lower() == "true"
FIREBASE_CRED_PATH = os.getenv("FIREBASE_CREDENTIALS", "")
FIREBASE_DB_URL = os.getenv("FIREBASE_DB_URL", "")

# ── In-memory fallback store ────────────────
_memory_store: Dict[str, Any] = {
    "crises": {},
    "logs": [],
}


def _get_firebase_db():
    """Initialize Firebase Admin SDK (lazy load)."""
    try:
        import firebase_admin
        from firebase_admin import credentials, db
        
        if not firebase_admin._apps:
            cred = credentials.Certificate(FIREBASE_CRED_PATH)
            firebase_admin.initialize_app(cred, {"databaseURL": FIREBASE_DB_URL})
        return db
    except ImportError:
        print("[Firebase] firebase-admin not installed. Using in-memory store.")
        return None
    except Exception as e:
        print(f"[Firebase] Init failed: {e}. Using in-memory store.")
        return None


class FirebaseClient:
    """
    Firebase Realtime Database client for SAHARA AI.
    Falls back to in-memory store when Firebase is unavailable.
    """

    def __init__(self):
        self.db = None
        if FIREBASE_ENABLED:
            self.db = _get_firebase_db()
        self.is_connected = self.db is not None
        mode = "Firebase Realtime DB" if self.is_connected else "In-memory store"
        print(f"[Firebase] Storage mode: {mode}")

    def save_crisis(self, crisis_id: str, data: dict) -> bool:
        """Persist a crisis analysis result."""
        try:
            if self.is_connected:
                ref = self.db.reference(f"crises/{crisis_id}")
                ref.set(data)
            else:
                _memory_store["crises"][crisis_id] = data
            return True
        except Exception as e:
            print(f"[Firebase] Save failed: {e}")
            _memory_store["crises"][crisis_id] = data
            return False

    def get_crisis(self, crisis_id: str) -> Optional[dict]:
        """Retrieve a stored crisis by ID."""
        try:
            if self.is_connected:
                ref = self.db.reference(f"crises/{crisis_id}")
                return ref.get()
            return _memory_store["crises"].get(crisis_id)
        except Exception as e:
            print(f"[Firebase] Read failed: {e}")
            return _memory_store["crises"].get(crisis_id)

    def save_log(self, log_entry: dict) -> bool:
        """Append an agent trace log entry."""
        try:
            log_entry["saved_at"] = datetime.utcnow().isoformat()
            if self.is_connected:
                ref = self.db.reference("logs")
                ref.push(log_entry)
            else:
                _memory_store["logs"].append(log_entry)
            return True
        except Exception as e:
            print(f"[Firebase] Log save failed: {e}")
            _memory_store["logs"].append(log_entry)
            return False

    def get_recent_logs(self, limit: int = 20) -> List[dict]:
        """Return recent agent trace logs."""
        try:
            if self.is_connected:
                ref = self.db.reference("logs")
                data = ref.order_by_child("saved_at").limit_to_last(limit).get()
                if data:
                    return list(data.values())
                return []
            return _memory_store["logs"][-limit:]
        except Exception as e:
            print(f"[Firebase] Log read failed: {e}")
            return _memory_store["logs"][-limit:]

    def get_all_crises(self) -> Dict[str, Any]:
        """Return all stored crises."""
        try:
            if self.is_connected:
                ref = self.db.reference("crises")
                return ref.get() or {}
            return _memory_store["crises"]
        except Exception:
            return _memory_store["crises"]


# Singleton instance
firebase = FirebaseClient()
