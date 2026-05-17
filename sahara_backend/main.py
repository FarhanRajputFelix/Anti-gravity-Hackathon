"""
SAHARA AI -- FastAPI Backend Entry Point v2.0
Pakistan's First Agentic Urban Crisis Response Operating System
Powered by Google Antigravity Orchestration + Gemini AI
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from routers.analyze import router as analyze_router
from routers.other import router as other_router
from routers.workflow import router as workflow_router

app = FastAPI(
    title="SAHARA AI -- Crisis Intelligence Backend",
    description="Multi-agent crisis response system for Pakistani cities. Powered by Google Antigravity + Gemini AI.",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# -- CORS -- Allow Flutter mobile app + web dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -- Register routers
app.include_router(analyze_router, prefix="/api", tags=["Analysis"])
app.include_router(other_router, prefix="/api", tags=["Crisis & Logs"])
app.include_router(workflow_router, prefix="/api", tags=["Orchestration Workflow"])

# -- Serve web dashboard as static files
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir, html=True), name="static")


@app.get("/dashboard", include_in_schema=False)
async def dashboard_redirect():
    """Redirect /dashboard to the web command center."""
    return RedirectResponse(url="/static/index.html")


@app.get("/", tags=["Health"])
async def root():
    return {
        "system": "SAHARA AI",
        "tagline": "Pakistan's First Agentic Urban Crisis Response Operating System",
        "version": "2.0.0",
        "orchestrator": "Google Antigravity v2.0 + Gemini AI",
        "agents": [
            "Signal Ingestion Agent",
            "Verification Agent",
            "Severity Analysis Agent",
            "Response Planning Agent",
            "Execution Simulation Agent",
            "Fallback & Recovery Agent",
        ],
        "status": "ONLINE",
        "dashboard": "/dashboard",
        "docs": "/docs",
    }


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy", "service": "SAHARA AI Backend v2.0"}
