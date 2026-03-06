# train_model.py
# ==========================================
# Thesis: Cloud-Based Inventory System
# Author: [Your Name]
# Description: Trains the Random Forest AI for Predictive Stock Ordering
# ==========================================

import pandas as pd
from sqlalchemy import create_engine
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import joblib

# 1. Connect to your PostgreSQL Database
# IMPORTANT: Change 'password' to your actual pgAdmin password
DATABASE_URL = "postgresql://postgres:Moth2710@localhost:5432/zando_db"
engine = create_engine(DATABASE_URL)

print("📊 Fetching 2 years of sales data from PostgreSQL...")

# 2. Extract the Data
# We grab the daily total sales for every SKU at every Branch
query = """
    SELECT 
        sku_id, 
        branch_id, 
        DATE(timestamp) as sale_date, 
        ABS(SUM(quantity_moved)) as total_sold
    FROM stock_movements 
    WHERE movement_type = 'Sale'
    GROUP BY sku_id, branch_id, DATE(timestamp)
    ORDER BY sale_date;
"""
df = pd.read_sql(query, engine)

# 3. Feature Engineering (Translating data for the AI)
# The AI cannot read raw calendar dates, so we split them into numbers
df['sale_date'] = pd.to_datetime(df['sale_date'])
df['day_of_week'] = df['sale_date'].dt.dayofweek
df['month'] = df['sale_date'].dt.month
df['year'] = df['sale_date'].dt.year

# Define our inputs (X) and the target we want to predict (y)
X = df[['sku_id', 'branch_id', 'day_of_week', 'month']]
y = df['total_sold']

# Split the data: 80% for the AI to study, 20% to test it like an exam
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# 4. Train the AI Brain
print("🧠 Training the Random Forest Algorithm... (This might take a few seconds)")
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Check the exam score
accuracy = model.score(X_test, y_test)
print(f"✅ AI Training Complete! Model Accuracy Score: {accuracy * 100:.2f}%")

# 5. Save the Brain to a File
joblib.dump(model, 'predictive_model.pkl')
print("💾 Model saved securely as 'predictive_model.pkl'.")
print("Your FastAPI backend can now use this file to predict when Zando will run out of stock!")