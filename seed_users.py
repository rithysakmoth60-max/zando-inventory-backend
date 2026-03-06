# seed_users.py
from database import SessionLocal, engine, Base
from models import User

def create_users():
    # 1. This magically creates the 'users' table in PostgreSQL if it doesn't exist yet!
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    # 2. Check if users are already inside
    if db.query(User).count() == 0:
        print("🌱 Injecting default users into the database...")
        
        # 3. Create the 3 roles for your presentation!
        admin = User(username="admin", password="123", role="admin")
        sale = User(username="staff", password="123", role="sale")
        customer = User(username="guest", password="123", role="customer")
        
        db.add_all([admin, sale, customer])
        db.commit()
        print("✅ SUCCESS: 3 Users created!")
        print("👑 Admin Login -> username: admin | pass: 123")
        print("💼 Sale Login  -> username: staff | pass: 123")
        print("🛍️ Guest Login -> username: guest | pass: 123")
    else:
        print("✅ Users table is already populated.")
        
    db.close() 

if __name__ == "__main__":
    create_users()
    