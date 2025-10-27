import os
from groq import Groq

api_key = os.getenv("GROQ_API_KEY")

if not api_key:
    print(" GROQ_API_KEY no encontrada")
    exit(1)

print(f"✓ API Key: {api_key[:20]}...")

try:
    client = Groq(api_key=api_key)
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile", 
        messages=[{"role": "user", "content": "Di 'API funcionando'"}],
        max_tokens=50
    )
    
    print(f" Respuesta: {response.choices[0].message.content}")
    print(" Groq API funcionando correctamente")
    
except Exception as e:
    print(f" Error: {e}")