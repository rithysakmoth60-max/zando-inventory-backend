# main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from database import init_db, SessionLocal
from models import InventoryLevel, SKU, Product, User
import joblib
import pandas as pd
from datetime import datetime

# --- Tell Python what data to expect from the Flutter Scanner ---
class StockReceiveRequest(BaseModel):
    sku_code: str
    quantity: int

# --- Tell Python what data to expect for a Sale ---
class StockSellRequest(BaseModel):
    sku_code: str
    quantity: int

# --- Tell Python what data to expect for Login ---
class LoginRequest(BaseModel):
    username: str
    password: str

# 🚀 NEW: Tell Python what data to expect for Registration ---
class RegisterRequest(BaseModel):
    username: str
    password: str
    role: str = "customer"  # Defaults to customer if not specified

# 1. Initialize the App
app = FastAPI(title="Zando Inventory API")

# 2. Load the AI Brain
try:
    ai_model = joblib.load('predictive_model.pkl')
    print("🧠 AI Model loaded successfully!")
except Exception as e:
    ai_model = None
    print("⚠️ Warning: Could not load AI model. Did you run train_model.py?")

# 3. Startup Event
@app.on_event("startup")
def on_startup():
    init_db()
    print("✅ Database connection successful! Tables are ready.")

# 4. Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 5. The Routes
@app.get("/")
def home():
    return {"message": "Zando Predictive Inventory System is Online"}

@app.get("/api/predict/{sku_id}/{branch_id}")
def predict_stock_need(sku_id: int, branch_id: int):
    if ai_model is None:
        return {"error": "AI Model is offline."}
    
    today = datetime.now()
    question_for_ai = pd.DataFrame([{
        'sku_id': sku_id,
        'branch_id': branch_id,
        'day_of_week': today.weekday(),
        'month': today.month
    }])

    predicted_sales = ai_model.predict(question_for_ai)[0]
    is_high_risk = predicted_sales >= 3
    
    return {
        "sku_id": sku_id,
        "branch_id": branch_id,
        "expected_sales_today": round(predicted_sales, 1),
        "stock_warning": "⚠️ HIGH DEMAND EXPECTED" if is_high_risk else "✅ Stock levels safe"
    }

@app.get("/api/inventory")
def get_live_inventory_with_ai():
    db = SessionLocal()
    
    results = db.query(InventoryLevel, SKU, Product)\
        .join(SKU, InventoryLevel.sku_id == SKU.id)\
        .join(Product, SKU.product_id == Product.id)\
        .filter(InventoryLevel.branch_id == 1)\
        .limit(20).all()
        
    inventory_list = []
    today = datetime.now()
    
    for inv, sku, prod in results:
        if ai_model is not None:
            question = pd.DataFrame([{
                'sku_id': sku.id, 
                'branch_id': 1, 
                'day_of_week': today.weekday(), 
                'month': today.month
            }])
            predicted_sales = ai_model.predict(question)[0]
        else:
            predicted_sales = 0
            
        inventory_list.append({
            "name": prod.name,
            "size": sku.size,
            "sku": sku.sku_code,
            "stock": inv.quantity,
            "predicted_sales": round(predicted_sales, 1),
            "is_high_risk": bool(predicted_sales >= 3),
            "image_url": f"https://picsum.photos/seed/{sku.id}/200"
        })
        
    db.close()
    return inventory_list

# --- The Barcode Receiving Endpoint ---
@app.post("/api/inventory/receive")
def receive_scanned_stock(request: StockReceiveRequest):
    db = SessionLocal()
    
    # 1. Search the database for the exact barcode/SKU string
    sku = db.query(SKU).filter(SKU.sku_code == request.sku_code).first()
    if not sku:
        db.close()
        raise HTTPException(status_code=404, detail=f"Barcode {request.sku_code} not found in system.")
        
    # 2. Find the inventory level for Zando BKK1 (Branch 1)
    inventory = db.query(InventoryLevel).filter(
        InventoryLevel.sku_id == sku.id,
        InventoryLevel.branch_id == 1
    ).first()
    
    if not inventory:
        db.close()
        raise HTTPException(status_code=404, detail="Inventory record not found for this branch.")
        
    # 3. Add the scanned quantity to fix the negative numbers!
    inventory.quantity += request.quantity
    db.commit()
    
    new_stock_level = inventory.quantity
    db.close()
    
    return {
        "success": True,
        "message": f"Added {request.quantity} units. New stock level: {new_stock_level}",
        "new_stock": new_stock_level
    }

# --- The Checkout / Sell Endpoint ---
@app.post("/api/inventory/sell")
def sell_scanned_stock(request: StockSellRequest):
    db = SessionLocal()
    
    # 1. Find the item
    sku = db.query(SKU).filter(SKU.sku_code == request.sku_code).first()
    if not sku:
        db.close()
        raise HTTPException(status_code=404, detail=f"Barcode {request.sku_code} not found.")
        
    # 2. Find the inventory for Branch 1
    inventory = db.query(InventoryLevel).filter(
        InventoryLevel.sku_id == sku.id,
        InventoryLevel.branch_id == 1
    ).first()
    
    if not inventory:
        db.close()
        raise HTTPException(status_code=404, detail="Inventory record not found.")
        
    # 3. SUBTRACT the sold quantity from the stock!
    inventory.quantity -= request.quantity
    db.commit()
    
    new_stock_level = inventory.quantity
    db.close()
    
    return {
        "success": True,
        "message": f"Sold {request.quantity} units. Stock is now: {new_stock_level}",
        "new_stock": new_stock_level
    }

# --- The AI Auto-Order Endpoint ---
@app.post("/api/inventory/auto-order")
def auto_order_high_risk_stock():
    db = SessionLocal()
    today = datetime.now()
    ordered_items = []
    total_ordered = 0
    
    # 1. Grab every item in the Branch 1 warehouse
    results = db.query(InventoryLevel, SKU, Product)\
        .join(SKU, InventoryLevel.sku_id == SKU.id)\
        .join(Product, SKU.product_id == Product.id)\
        .filter(InventoryLevel.branch_id == 1).all()
        
    for inv, sku, prod in results:
        # 2. Ask the AI for the prediction on this specific item
        if ai_model is not None:
            question = pd.DataFrame([{
                'sku_id': sku.id, 
                'branch_id': 1, 
                'day_of_week': today.weekday(), 
                'month': today.month
            }])
            predicted_sales = ai_model.predict(question)[0]
            
            # 3. THE MAGIC: If the AI says it's high risk, order 50 more!
            if predicted_sales >= 3:
                inv.quantity += 50
                ordered_items.append(sku.sku_code)
                total_ordered += 50
                
    # 4. Save all the new orders to PostgreSQL
    if total_ordered > 0:
        db.commit()
        
    db.close()
    
    return {
        "success": True,
        "message": f"AI automatically ordered 50 units for {len(ordered_items)} high-risk items.",
        "items_restocked": ordered_items
    }

# --- The Login Authentication Endpoint ---
@app.post("/api/login")
def login(req: LoginRequest):
    db = SessionLocal()
    
    user = db.query(User).filter(
        User.username == req.username, 
        User.password == req.password
    ).first()
    
    db.close()
    
    if user:
        return {
            "success": True, 
            "role": user.role, 
            "username": user.username,
            "message": f"Welcome back, {user.username}!"
        }
    else:
        return {
            "success": False, 
            "message": "❌ Invalid username or password"
        }

# 🚀 NEW: The Registration Endpoint ---
@app.post("/api/register")
def register(req: RegisterRequest):
    db = SessionLocal()
    
    # 1. Check if the username already exists
    existing_user = db.query(User).filter(User.username == req.username).first()
    if existing_user:
        db.close()
        raise HTTPException(status_code=400, detail="Username already exists. Please choose another one.")
        
    # 2. Create the new user
    new_user = User(
        username=req.username,
        password=req.password,
        role=req.role
    )
    
    # 3. Save to database
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    db.close()
    
    return {
        "success": True,
        "message": f"Account created successfully for {new_user.username}!",
        "username": new_user.username,
        "role": new_user.role
    }