import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.background import BackgroundScheduler

from app.core.config import settings
from app.db.database import engine, Base, SessionLocal
from app.services.reminder_service import ReminderService
from app.routers import auth, tasks, settings as settings_router, reminders, assistant

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("main")

# Auto-create tables for development if using SQLite
Base.metadata.create_all(bind=engine)

scheduler = BackgroundScheduler()


def run_scheduled_reminder_check():
    """Periodic job executed every SCHEDULER_INTERVAL_SECONDS."""
    db = SessionLocal()
    try:
        dispatched = ReminderService.check_and_dispatch_due_reminders(db)
        if dispatched > 0:
            logger.info(f"Scheduled check dispatched {dispatched} due reminders")
    except Exception as e:
        logger.error(f"Error in scheduled reminder check: {e}")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start APScheduler
    logger.info("Starting background reminder scheduler...")
    scheduler.add_job(
        run_scheduled_reminder_check,
        "interval",
        seconds=settings.SCHEDULER_INTERVAL_SECONDS,
        id="check_due_reminders_job",
        replace_existing=True,
    )
    scheduler.start()
    yield
    # Shutdown: Stop APScheduler
    logger.info("Stopping background reminder scheduler...")
    scheduler.shutdown(wait=False)


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Backend API for Bilingual Voice & Text AI Task Assistant",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS Middleware (Configured for Flutter Web & Mobile / Emulators)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.merged_cors_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(settings_router.router, prefix=settings.API_V1_STR)
app.include_router(tasks.router, prefix=settings.API_V1_STR)
app.include_router(reminders.router, prefix=settings.API_V1_STR)
app.include_router(assistant.router, prefix=settings.API_V1_STR)


@app.get("/", tags=["Health"])
def root():
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}",
        "environment": settings.ENVIRONMENT,
        "docs_url": "/docs",
        "status": "online",
    }


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok"}
