# export_report.py
import pandas as pd
import joblib
from datetime import datetime
from database import SessionLocal
from models import InventoryLevel, SKU, Product

def generate_thesis_report():
    print("📊 Connecting to the Zando Enterprise database...")
    db = SessionLocal()
    
    # 1. Load the AI Brain
    try:
        ai_model = joblib.load('predictive_model.pkl')
        print("🧠 AI Model loaded successfully.")
    except Exception as e:
        ai_model = None
        print("⚠️ Warning: AI Model not found. Predictions will be 0.")

    print("🔍 Gathering live warehouse data...")
    
    # 2. Query the database
    results = db.query(InventoryLevel, SKU, Product)\
        .join(SKU, InventoryLevel.sku_id == SKU.id)\
        .join(Product, SKU.product_id == Product.id)\
        .filter(InventoryLevel.branch_id == 1).all()

    report_data = []
    today = datetime.now()

    # 3. Format the data for the professors
    for inv, sku, prod in results:
        if ai_model is not None:
            question = pd.DataFrame([{
                'sku_id': sku.id, 
                'branch_id': 1, 
                'day_of_week': today.weekday(), 
                'month': today.month
            }])
            predicted_sales = round(ai_model.predict(question)[0], 1)
        else:
            predicted_sales = 0
            
        # Make the alert text look professional for the report
        risk_status = "⚠️ HIGH RISK (Auto-Order Recommended)" if predicted_sales >= 3 else "✅ Safe"

        report_data.append({
            "Product Name": prod.name,
            "SKU / Barcode": sku.sku_code,
            "Size": sku.size,
            "Current Stock": inv.quantity,
            "AI Forecast (Units/Day)": predicted_sales,
            "System Status": risk_status,
            "Timestamp": today.strftime("%Y-%m-%d %H:%M")
        })

    db.close()
    
    # 4. Convert to a Professional Spreadsheet format using Pandas
    print("📝 Generating Spreadsheet...")
    df = pd.DataFrame(report_data)
    
    # We use CSV with 'utf-8-sig' so it opens perfectly in Microsoft Excel
    filename = "Zando_Thesis_Appendix_Report.csv"
    df.to_csv(filename, index=False, encoding='utf-8-sig')
    
    print(f"✅ SUCCESS: Enterprise Report saved as '{filename}'!")
    print("📂 Go to your project folder, double-click the file to open in Excel, and attach it to your thesis appendix!")

if __name__ == "__main__":
    generate_thesis_report()