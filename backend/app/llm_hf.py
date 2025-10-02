import os
from typing import Optional
from huggingface_hub import InferenceClient


class HFClient:
    def __init__(self, model: Optional[str] = None):
        token = os.getenv("HUGGINGFACE_TOKEN", "")
        self.model = model or os.getenv("HF_MODEL", "meta-llama/Meta-Llama-3-8B-Instruct")
        self.client = InferenceClient(token=token)

    def build_prompt(self, user_message: str, objective: Optional[str], retrieved_context: str) -> str:
        parts = []
        if objective:
            parts.append(f"Objective: {objective}")
        if retrieved_context:
            parts.append("Context sources:\n" + retrieved_context)
        parts.append("User:\n" + user_message)
        parts.append("Instructions: Answer concisely using the provided context when relevant.")
        return "\n\n".join(parts)

    def generate_text(self, prompt: str) -> str:
        try:
            # Use text-generation with simple parameters; relies on hosted model
            resp = self.client.text_generation(
                model=self.model,
                prompt=prompt,
                max_new_tokens=256,
                temperature=0.2,
                do_sample=False,
                return_full_text=False,
            )
            return resp
        except Exception as e:
            return f"[LLM error] {e}"



