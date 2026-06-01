"""
Converts a sentence-transformers model to TFLite format and saves it as
assets/model.tflite. This is run by the GitHub Actions CI before building
the APK so the apk ships with the model embedded.
"""
from sentence_transformers import SentenceTransformer
import tensorflow as tf
import os

model = SentenceTransformer('all-MiniLM-L6-v2')
model.save('model_saved')

converter = tf.lite.TFLiteConverter.from_saved_model('model_saved')
tflite_model = converter.convert()

os.makedirs('assets', exist_ok=True)
with open('assets/model.tflite', 'wb') as f:
    f.write(tflite_model)

print("Model saved to assets/model.tflite")
