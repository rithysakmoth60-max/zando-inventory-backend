# main.py
import warnings
warnings.filterwarnings("ignore", category=UserWarning) # 🚀 Stops the Scikit-Learn log spam!

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from database import init_db, SessionLocal
from models import InventoryLevel, SKU, Product, User, Order # 🚀 Added Order import
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

# --- Tell Python what data to expect for Registration ---
class RegisterRequest(BaseModel):
    username: str
    password: str
    role: str = "customer"  # Defaults to customer if not specified

# 🚀 NEW: Tell Python what data to expect for an Order ---
class OrderRequest(BaseModel):
    sku_code: str
    quantity: int
    customer_username: str
    product_name: str

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
    
    sku = db.query(SKU).filter(SKU.sku_code == request.sku_code).first()
    if not sku:
        db.close()
        raise HTTPException(status_code=404, detail=f"Barcode {request.sku_code} not found in system.")
        
    inventory = db.query(InventoryLevel).filter(
        InventoryLevel.sku_id == sku.id,
        InventoryLevel.branch_id == 1
    ).first()
    
    if not inventory:
        db.close()
        raise HTTPException(status_code=404, detail="Inventory record not found for this branch.")
        
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
    
    sku = db.query(SKU).filter(SKU.sku_code == request.sku_code).first()
    if not sku:
        db.close()
        raise HTTPException(status_code=404, detail=f"Barcode {request.sku_code} not found.")
        
    inventory = db.query(InventoryLevel).filter(
        InventoryLevel.sku_id == sku.id,
        InventoryLevel.branch_id == 1
    ).first()
    
    if not inventory:
        db.close()
        raise HTTPException(status_code=404, detail="Inventory record not found.")
        
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
    
    results = db.query(InventoryLevel, SKU, Product)\
        .join(SKU, InventoryLevel.sku_id == SKU.id)\
        .join(Product, SKU.product_id == Product.id)\
        .filter(InventoryLevel.branch_id == 1).all()
        
    for inv, sku, prod in results:
        if ai_model is not None:
            question = pd.DataFrame([{
                'sku_id': sku.id, 
                'branch_id': 1, 
                'day_of_week': today.weekday(), 
                'month': today.month
            }])
            predicted_sales = ai_model.predict(question)[0]
            
            if predicted_sales >= 3:
                inv.quantity += 50
                ordered_items.append(sku.sku_code)
                total_ordered += 50
                
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

# --- The Registration Endpoint ---
@app.post("/api/register")
def register(req: RegisterRequest):
    db = SessionLocal()
    
    existing_user = db.query(User).filter(User.username == req.username).first()
    if existing_user:
        db.close()
        raise HTTPException(status_code=400, detail="Username already exists. Please choose another one.")
        
    new_user = User(
        username=req.username,
        password=req.password,
        role=req.role
    )
    
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

# 🚀 NEW: The Order Creation Endpoint ---
@app.post("/api/orders")
def place_order(req: OrderRequest):
    db = SessionLocal()
    
    # 1. Deduct the stock
    sku = db.query(SKU).filter(SKU.sku_code == req.sku_code).first()
    if sku:
        inventory = db.query(InventoryLevel).filter(
            InventoryLevel.sku_id == sku.id, 
            InventoryLevel.branch_id == 1
        ).first()
        if inventory and inventory.quantity >= req.quantity:
            inventory.quantity -= req.quantity
            
    # 2. Save the Order Receipt
    new_order = Order(
        customer_username=req.customer_username,
        sku_code=req.sku_code,
        product_name=req.product_name,
        quantity=req.quantity
    )
    
    db.add(new_order)
    db.commit()
    db.close()
    
    return {"success": True, "message": "Order placed successfully!"}

# 🚀 NEW: The Order Retrieval Endpoint ---
@app.get("/api/orders/{username}")
def get_customer_orders(username: str):
    db = SessionLocal()
    # Fetch orders from newest to oldest
    orders = db.query(Order).filter(Order.customer_username == username).order_by(Order.order_date.desc()).all()
    db.close()
    
    return [
        {
            "id": o.id,
            "product_name": o.product_name,
            "sku_code": o.sku_code,
            "quantity": o.quantity,
            "order_date": o.order_date.strftime("%Y-%m-%d %H:%M")
        }
        for o in orders
    ]