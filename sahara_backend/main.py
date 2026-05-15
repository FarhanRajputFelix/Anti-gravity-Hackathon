"""
SAHARA AI — FastAPI Backend Entry Point
Pakistan's First Agentic Urban Crisis Response Operating System
Powered by Google Antigravity Orchestration
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.analyze import router as analyze_router
from routers.other import router as other_router

app = FastAPI(
    title="SAHARA AI — Crisis Intelligence Backend",
    description="Multi-agent crisis response system for Pakistani cities. Powered by Google Antigravity.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS — Allow Flutter mobile app ───────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production: restrict to your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Register routers ───────────────────────────────
app.include_router(analyze_router, prefix="/api", tags=["Analysis"])
app.include_router(other_router, prefix="/api", tags=["Crisis & Logs"])


@app.get("/", tags=["Health"])
async def root():
    return {
        "system": "SAHARA AI",
        "tagline": "Pakistan's First Agentic Urban Crisis Response Operating System",
        "version": "1.0.0",
        "orchestrator": "Google Antigravity v1.0",
        "agents": [
            "Signal Ingestion Agent",
            "Verification Agent",
            "Severity Analysis Agent",
            "Response Planning Agent",
            "Execution Simulation Agent",
            "Fallback & Recovery Agent",
        ],
        "status": "ONLINE",
        "docs": "/docs",
    }


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy", "service": "SAHARA AI Backend"}
