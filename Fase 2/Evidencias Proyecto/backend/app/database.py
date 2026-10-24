import os
from pathlib import Path

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase


def _database_url() -> str:
    value = os.getenv("DATABASE_URL")
    if not value:
        db_path = Path(__file__).resolve().parents[1] / "corestream.db"
        return f"sqlite+aiosqlite:///{db_path.as_posix()}"
    if value.startswith("postgres://"):
        return value.replace("postgres://", "postgresql+asyncpg://", 1)
    if value.startswith("postgresql://"):
        return value.replace("postgresql://", "postgresql+asyncpg://", 1)
    return value


class Base(DeclarativeBase):
    pass


engine = create_async_engine(_database_url(), future=True)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_db():
    async with SessionLocal() as session:
        yield session


async def create_tables() -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
