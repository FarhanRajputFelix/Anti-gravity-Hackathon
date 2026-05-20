"""
SAHARA AI — Firebase Client (production-ready)
Persists crises, WhatsApp reports, and agent logs to Firebase Realtime DB.

Production deployment (Render):
  1. Add env vars:
       FIREBASE_ENABLED=true
       FIREBASE_DB_URL=https://your-project-default-rtdb.firebaseio.com
       FIREBASE_CREDENTIALS_JSON=<paste your full service-account JSON here>
  2. Restart service.

Local dev (file-based):
  Set FIREBASE_CREDENTIALS=/path/to/service-account.json instead.

If Firebase is not configured, falls back gracefully to in-memory store.
"""

import os
import json
from datetime import datetime
from typing import Optional, Dict, Any, List

FIREBASE_ENABLED = os.getenv("FIREBASE_ENABLED", "false").lower() == "true"
FIREBASE_CRED_PATH = os.getenv("FIREBASE_CREDENTIALS", "")
FIREBASE_CRED_JSON = os.getenv("FIREBASE_CREDENTIALS_JSON", "")
FIREBASE_DB_URL = os.getenv("FIREBASE_DB_URL", "")

_memory_store: Dict[str, Any] = {
    "crises": {},
    "logs": [],
    "whatsapp_reports": [],
}


def _get_firebase_db():
    """Initialize Firebase Admin SDK from env-var JSON OR file path. Lazy load."""
    try:
        import firebase_admin
        from firebase_admin import credentials, db

        if not firebase_admin._apps:
            # Prefer env-var JSON (Render-friendly) over file path
            if FIREBASE_CRED_JSON:
                try:
                    cred_dict = json.loads(FIREBASE_CRED_JSON)
                    cred = credentials.Certificate(cred_dict)
                except json.JSONDecodeError as e:
                    print(f"[Firebase] FIREBASE_CREDENTIALS_JSON is not valid JSON: {e}")
                    return None
            elif FIREBASE_CRED_PATH and os.path.exists(FIREBASE_CRED_PATH):
                cred = credentials.Certificate(FIREBASE_CRED_PATH)
            else:
                print("[Firebase] No credentials provided (set FIREBASE_CREDENTIALS_JSON or FIREBASE_CREDENTIALS).")
                return None

            if not FIREBASE_DB_URL:
                print("[Firebase] FIREBASE_DB_URL not set — cannot connect.")
                return None

            firebase_admin.initialize_app(cred, {"databaseURL": FIREBASE_DB_URL})
            print(f"[Firebase] Connected to {FIREBASE_DB_URL}")
        return db
    except ImportError:
        print("[Firebase] firebase-admin not installed. Using in-memory store.")
        return None
    except Exception as e:
        print(f"[Firebase] Init failed: {e}. Using in-memory store.")
        return None


class FirebaseClient:
    """Persistent storage with in-memory fallback."""

    def __init__(self):
        self.db = None
        if FIREBASE_ENABLED:
            self.db = _get_firebase_db()
        self.is_connected = self.db is not None
        mode = "Firebase Realtime DB" if self.is_connected else "In-memory store"
        print(f"[Firebase] Storage mode: {mode}")

    # ─── Crises ──────────────────────────────────────
    def save_crisis(self, crisis_id: str, data: dict) -> bool:
        try:
            # Sanitize for Firebase (no None values, no $ # [ ] / . in keys)
            clean = _sanitize_for_firebase(data)
            if self.is_connected:
                self.db.reference(f"crises/{crisis_id}").set(clean)
            _memory_store["crises"][crisis_id] = data
            return True
        except Exception as e:
            print(f"[Firebase] save_crisis failed: {e}")
            _memory_store["crises"][crisis_id] = data
            return False

    def get_crisis(self, crisis_id: str) -> Optional[dict]:
        try:
            if self.is_connected:
                data = self.db.reference(f"crises/{crisis_id}").get()
                if data:
                    return data
            return _memory_store["crises"].get(crisis_id)
        except Exception:
            return _memory_store["crises"].get(crisis_id)

    def get_all_crises(self) -> Dict[str, Any]:
        try:
            if self.is_connected:
                return self.db.reference("crises").get() or {}
            return _memory_store["crises"]
        except Exception:
            return _memory_store["crises"]

    # ─── Logs ────────────────────────────────────────
    def save_log(self, log_entry: dict) -> bool:
        try:
            log_entry["saved_at"] = datetime.utcnow().isoformat()
            clean = _sanitize_for_firebase(log_entry)
            if self.is_connected:
                self.db.reference("logs").push(clean)
            _memory_store["logs"].append(log_entry)
            return True
        except Exception as e:
            print(f"[Firebase] save_log failed: {e}")
            _memory_store["logs"].append(log_entry)
            return False

    def get_recent_logs(self, limit: int = 20) -> List[dict]:
        try:
            if self.is_connected:
                data = self.db.reference("logs").order_by_child("saved_at").limit_to_last(limit).get()
                if data:
                    return list(data.values())
            return _memory_store["logs"][-limit:]
        except Exception:
            return _memory_store["logs"][-limit:]

    # ─── WhatsApp reports ────────────────────────────
    def save_whatsapp_report(self, report: dict) -> bool:
        try:
            clean = _sanitize_for_firebase(report)
            if self.is_connected:
                self.db.reference("whatsapp_reports").push(clean)
            _memory_store["whatsapp_reports"].insert(0, report)
            del _memory_store["whatsapp_reports"][50:]
            return True
        except Exception as e:
            print(f"[Firebase] save_whatsapp_report failed: {e}")
            return False

    def get_whatsapp_reports(self, limit: int = 50) -> List[dict]:
        try:
            if self.is_connected:
                data = self.db.reference("whatsapp_reports").order_by_key().limit_to_last(limit).get()
                if data:
                    return list(reversed(list(data.values())))
            return _memory_store["whatsapp_reports"][:limit]
        except Exception:
            return _memory_store["whatsapp_reports"][:limit]


def _sanitize_for_firebase(obj):
    """Firebase Realtime DB rejects None, NaN, and certain key chars. Clean recursively."""
    if obj is None:
        return ""
    if isinstance(obj, dict):
        return {_clean_key(k): _sanitize_for_firebase(v) for k, v in obj.items() if v is not None}
    if isinstance(obj, list):
        return [_sanitize_for_firebase(v) for v in obj if v is not None]
    if isinstance(obj, float):
        # Firebase doesn't accept NaN or Infinity
        import math
        if math.isnan(obj) or math.isinf(obj):
            return 0
        return obj
    return obj


def _clean_key(k: str) -> str:
    """Firebase rejects keys with . $ # [ ] / chars."""
    s = str(k)
    for ch in [".", "$", "#", "[", "]", "/"]:
        s = s.replace(ch, "_")
    return s


# Singleton
firebase = FirebaseClient()
