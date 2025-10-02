import os
from typing import Optional
import google.generativeai as genai


class GeminiClient:
    def __init__(self, model: str = ""):
        key = os.getenv("GEMINI_API_KEY")
        if not key:
            # Fallback to inline default if user provided during dev; overridable by env
            key = ""
        if key:
            genai.configure(api_key=key)
        env_model = os.getenv("GEMINI_MODEL")
        self.model_name = env_model or model or "gemini-1.5-flash-8b"

    def build_prompt(self, user_message: str, objective: Optional[str], retrieved_context: str) -> str:
        parts = []
        if objective:
            parts.append(f"Objective: {objective}")
        if retrieved_context:
            parts.append("Context sources:\n" + retrieved_context)
        parts.append("User:\n" + user_message)
        parts.append(
            "Instructions: Provide clear, concise study guidance with examples. Offer pacing and short breaks if stress is high. Keep response under 300 words."
        )
        return "\n\n".join(parts)

    def generate_text(self, prompt: str) -> str:
        candidates = [
            self.model_name,
            "gemini-1.5-flash",
            "gemini-1.5-flash-8b",
            "gemini-1.5-flash-latest",
        ]
        seen = set()
        for name in candidates:
            if not name or name in seen:
                continue
            seen.add(name)
            try:
                model = genai.GenerativeModel(name)
                resp = model.generate_content(prompt)
                return getattr(resp, "text", "") or ""
            except Exception as e:
                last_err = str(e)
                continue
        # As last resort, try the first list_models() entry that supports generateContent
        try:
            for m in genai.list_models():
                methods = getattr(m, "supported_generation_methods", [])
                if "generateContent" in methods:
                    model = genai.GenerativeModel(m.name)
                    resp = model.generate_content(prompt)
                    return getattr(resp, "text", "") or ""
        except Exception:
            pass
        return f"[LLM error] {last_err if 'last_err' in locals() else 'unknown error'}"


