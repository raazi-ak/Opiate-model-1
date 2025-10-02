import os
import requests
from typing import Optional


class OllamaClient:
    def __init__(self, model: Optional[str] = None, host: Optional[str] = None):
        self.model = model or os.getenv("OLLAMA_MODEL", "llama3.2:3b")
        self.host = host or os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")

    def build_prompt(self, user_message: str, objective: Optional[str], retrieved_context: str) -> str:
        parts = []
        if objective:
            parts.append(f"Objective: {objective}")
        if retrieved_context:
            parts.append("Context:\n" + retrieved_context)
        parts.append("Question:\n" + user_message)
        parts.append("Answer clearly and concisely using the context when relevant.")
        return "\n\n".join(parts)

    def generate_text(self, prompt: str) -> str:
        try:
            url = f"{self.host}/api/generate"
            resp = requests.post(url, json={
                "model": self.model,
                "prompt": prompt,
                "stream": False,
                "options": {"temperature": 0.2}
            }, timeout=120)
            resp.raise_for_status()
            data = resp.json()
            return data.get("response", "")
        except Exception as e:
            return f"[LLM error] {e}"


