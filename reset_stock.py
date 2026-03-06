# seed_data.py
# ==========================================
# Thesis: Cloud-Based Inventory System
# Author: [Your Name]
# Description: Generates 2 years of fake sales data AND injects default users
# ==========================================

import random
from datetime import datetime, timedelta
from database import SessionLocal, init_db
from models import Branch, Product, SKU, InventoryLevel, StockMovement, User

def generate_fake_data():
    db = SessionLocal()
    
    print("Clearing old data and creating fresh tables...")
    init_db() # Ensures tables exist

    # --- NEW: 1. Inject Users for RBAC ---
    print("🌱 Injecting default users into the database...")
    admin = User(username="admin", password="123", role="admin")
    sale = User(username="staff", password="123", role="sale")
    customer = User(username="guest", password="123", role="customer")
    db.add_all([admin, sale, customer])
    db.commit()
    print("✅ 3 Default Users created! (admin, staff, guest)")

    # 2. Create Branches (Using real Phnom Penh locations for realism)
    branches_data = ["Zando BKK1", "Zando TK Avenue", "Main Warehouse"]
    db_branches = []
    for name in branches_data:
        branch = Branch(name=name, location_type="Store" if "Warehouse" not in name else "Warehouse")
        db.add(branch)
        db_branches.append(branch)
    db.commit()
    print("✅ Branches created.")

    # 3. Create Products
    products_data = [
        {"name": "Classic Denim Jacket", "category": "Menswear", "price": 45.00},
        {"name": "Basic Cotton T-Shirt", "category": "Unisex", "price": 12.00},
        {"name": "Black Chinos", "category": "Menswear", "price": 30.00}
    ]
    
    db_skus = []
    sizes = ["S", "M", "L"]
    colors = ["Black", "Blue", "White"]

    for p_data in products_data:
        product = Product(name=p_data["name"], category=p_data["category"], base_price=p_data["price"])
        db.add(product)
        db.commit()
        
        # Create SKUs (Variations of sizes and colors for each product)
        for size in sizes:
            for color in colors:
                sku_code = f"{p_data['name'][:3].upper()}-{color[:3].upper()}-{size}"
                sku = SKU(product_id=product.id, sku_code=sku_code, size=size, color=color)
                db.add(sku)
                db.commit()
                db_skus.append(sku)
                
                # Set initial inventory levels to 100 for the stores
                for branch in db_branches:
                    inv = InventoryLevel(sku_id=sku.id, branch_id=branch.id, quantity=100) 
                    db.add(inv)
        db.commit()
    print("✅ Products, SKUs, and Initial Inventory created.")

    # 4. Generate 2 Years of Daily Sales (The Machine Learning Goldmine)
    print("⏳ Generating 2 years of daily sales transactions... This might take a few seconds.")
    start_date = datetime.now() - timedelta(days=730) # 2 years ago
    
    for i in range(730):
        current_date = start_date + timedelta(days=i)
        
        # Every day, each store sells a random amount of each item
        for branch in db_branches:
            if branch.location_type == "Warehouse": continue # Warehouse doesn't sell directly to customers
            
            for sku in db_skus:
                # Let's make Medium (M) sizes sell slightly more often to give the AI a pattern to find
                max_sales = 5 if sku.size == "M" else 2 
                daily_sold = random.randint(0, max_sales)
                
                if daily_sold > 0:
                    movement = StockMovement(
                        sku_id=sku.id,
                        branch_id=branch.id,
                        quantity_moved=-daily_sold, # Negative because it's a sale
                        movement_type="Sale",
                        timestamp=current_date
                    )
                    db.add(movement)
                    
                    # Deduct from current inventory
                    inv = db.query(InventoryLevel).filter_by(sku_id=sku.id, branch_id=branch.id).first()
                    if inv:
                        inv.quantity -= daily_sold
                        
    db.commit()
    db.close()
    print("🚀 SUCCESS! Users, branches, and 2 years of fake sales data injected into PostgreSQL.")

if __name__ == "__main__":
    generate_fake_data()