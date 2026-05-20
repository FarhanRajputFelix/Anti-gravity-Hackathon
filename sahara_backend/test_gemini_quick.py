import asyncio, sys, os, warnings
sys.path.insert(0, '.')
# Reads from your .env / shell environment — never hard-code real keys.
from dotenv import load_dotenv
load_dotenv()

warnings.filterwarnings('ignore')

async def test():
    import google.generativeai as genai
    key = os.environ['GEMINI_API_KEY']
    genai.configure(api_key=key)

    # List available models
    print("Available models:")
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            print(f"  {m.name}")
            break  # just show first one

asyncio.run(test())
