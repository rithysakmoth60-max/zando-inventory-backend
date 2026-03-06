# models.py
from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime
from sqlalchemy.orm import declarative_base
from datetime import datetime

Base = declarative_base()

# 1. Store Locations (Branches & Warehouses)
class Branch(Base):
    __tablename__ = "branches"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True) # e.g., "TK Avenue", "Main Warehouse"
    location_type = Column(String)    # e.g., "Store", "Warehouse"

# 2. General Product (The parent item)
class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True) # e.g., "Classic Denim Jacket"
    category = Column(String)         # e.g., "Menswear", "Womenswear"
    base_price = Column(Float)

# 3. SKU (The specific variation - Crucial for apparel!)
class SKU(Base):
    __tablename__ = "skus"
    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"))
    sku_code = Column(String, unique=True, index=True) # e.g., "JKT-DEN-BLU-M"
    size = Column(String)  # e.g., "S", "M", "L"
    color = Column(String) # e.g., "Blue", "Black"

# 4. Current Stock Levels at each branch
class InventoryLevel(Base):
    __tablename__ = "inventory_levels"
    id = Column(Integer, primary_key=True, index=True)
    sku_id = Column(Integer, ForeignKey("skus.id"))
    branch_id = Column(Integer, ForeignKey("branches.id"))
    quantity = Column(Integer, default=0)

# 5. Historical Movements (The goldmine for Machine Learning)
class StockMovement(Base):
    __tablename__ = "stock_movements"
    id = Column(Integer, primary_key=True, index=True)
    sku_id = Column(Integer, ForeignKey("skus.id"))
    branch_id = Column(Integer, ForeignKey("branches.id"))
    quantity_moved = Column(Integer) # Negative for sales, positive for restocks
    movement_type = Column(String)   # "Sale", "Restock", "Transfer"
    timestamp = Column(DateTime, default=datetime.utcnow)

# 6. Users for Role-Based Access Control
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password = Column(String)  # Note: Plain text for demo simplicity!
    role = Column(String)      # 'admin', 'sale', or 'customer'