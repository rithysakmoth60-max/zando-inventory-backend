# seed_data.py
import random
from datetime import datetime, timedelta
from database import SessionLocal, init_db
from models import Branch, Product, SKU, InventoryLevel, StockMovement, User

def generate_fake_data():
    db = SessionLocal()
    
    print("Clearing old data and creating fresh tables...")
    init_db() # Ensures tables exist

    print("🌱 Injecting default users into the database...")
    admin = User(username="admin", password="123", role="admin")
    sale = User(username="staff", password="123", role="sale")
    customer = User(username="guest", password="123", role="customer")
    db.add_all([admin, sale, customer])
    
    # Create Branches
    branches_data = ["Zando BKK1", "Zando TK Avenue", "Main Warehouse"]
    db_branches = []
    for name in branches_data:
        branch = Branch(name=name, location_type="Store" if "Warehouse" not in name else "Warehouse")
        db.add(branch)
        db_branches.append(branch)

    # Create Products
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
        db.commit() # Need product ID for SKUs
        
        for size in sizes:
            for color in colors:
                sku_code = f"{p_data['name'][:3].upper()}-{color[:3].upper()}-{size}"
                sku = SKU(product_id=product.id, sku_code=sku_code, size=size, color=color)
                db.add(sku)
                db.commit() # Need SKU ID for inventory
                db_skus.append(sku)
                
                for branch in db_branches:
                    inv = InventoryLevel(sku_id=sku.id, branch_id=branch.id, quantity=100) 
                    db.add(inv)
                    
    db.commit()
    print("✅ Users, Branches, Products, and Initial Inventory created.")

    # Generate 60 Days of Daily Sales (Cloud Optimized!)
    print("⏳ Generating 60 days of sales transactions for the cloud...")
    start_date = datetime.now() - timedelta(days=60) 
    
    for i in range(60):
        current_date = start_date + timedelta(days=i)
        
        for branch in db_branches:
            if branch.location_type == "Warehouse": continue 
            
            for sku in db_skus:
                max_sales = 5 if sku.size == "M" else 2 
                daily_sold = random.randint(0, max_sales)
                
                if daily_sold > 0:
                    movement = StockMovement(
                        sku_id=sku.id,
                        branch_id=branch.id,
                        quantity_moved=-daily_sold,
                        movement_type="Sale",
                        timestamp=current_date
                    )
                    db.add(movement)
                    
                    inv = db.query(InventoryLevel).filter_by(sku_id=sku.id, branch_id=branch.id).first()
                    if inv:
                        inv.quantity -= daily_sold
                        
    # Commit all the sales at once to save internet bandwidth!
    db.commit()
    db.close()
    print("🚀 SUCCESS! Cloud database is fully populated and ready!")

if __name__ == "__main__":
    generate_fake_data()