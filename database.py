# database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Base

SQLALCHEMY_DATABASE_URL = "postgresql://postgres.xoyklwlwurrvzskwebro:ZandoThesis2026@aws-1-ap-northeast-1.pooler.supabase.com:6543/postgres"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db():
    # NEW: Tell Python to actually delete old cloud tables before making fresh ones!
    Base.metadata.drop_all(bind=engine) 
    Base.metadata.create_all(bind=engine)