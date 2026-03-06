# compress_model.py
import joblib
import os

def shrink_model():
    original_file = 'predictive_model.pkl'
    
    # 1. Check how big it is currently
    original_size = os.path.getsize(original_file) / (1024 * 1024)
    print(f"📦 Original Model Size: {original_size:.2f} MB")
    
    print("🧠 Loading the giant model into memory...")
    model = joblib.load(original_file)
    
    print("🗜️ Compressing the model...")
    # 2. Re-save it with Maximum Compression (Level 9)
    joblib.dump(model, original_file, compress=9)
    
    # 3. Check the new size!
    new_size = os.path.getsize(original_file) / (1024 * 1024)
    print(f"✅ New Compressed Size: {new_size:.2f} MB")
    print(f"📉 You shrunk the AI by {((original_size - new_size) / original_size) * 100:.1f}%!")

if __name__ == "__main__":
    shrink_model()