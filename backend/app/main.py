from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Optional
import os
import uvicorn
from dotenv import load_dotenv

from .rag import RagPipeline
from .llm import GeminiClient
from .llm_hf import HFClient
from .llm_ollama import OllamaClient


APP_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(APP_DIR, "..", ".."))
UPLOAD_DIR = os.path.join(ROOT_DIR, "data", "uploads")
INDEX_DIR = os.path.join(ROOT_DIR, "data", "index")


os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(INDEX_DIR, exist_ok=True)

# Load env from backend/.env
ENV_PATH = os.path.abspath(os.path.join(APP_DIR, "..", ".env"))
if os.path.exists(ENV_PATH):
    load_dotenv(ENV_PATH)


app = FastAPI(title="Study RAG Backend", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


rag: Optional[RagPipeline] = None
llm: Optional[object] = None


def get_rag() -> RagPipeline:
    global rag
    if rag is None:
        rag = RagPipeline(index_dir=INDEX_DIR)
    return rag


def get_llm():
    global llm
    if llm is None:
        provider = os.getenv("LLM_PROVIDER", "ollama").lower()
        if provider == "hf" or provider == "huggingface":
            llm = HFClient()
        elif provider == "ollama":
            llm = OllamaClient()
        else:
            llm = GeminiClient()
    return llm


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/upload")
async def upload_files(files: List[UploadFile] = File(...)):
    saved = []
    for f in files:
        name = os.path.basename(f.filename)
        if not name:
            continue
        out_path = os.path.join(UPLOAD_DIR, name)
        data = await f.read()
        with open(out_path, "wb") as h:
            h.write(data)
        saved.append(name)
    return {"saved": saved}


@app.post("/ingest")
def ingest():
    rp = get_rag()
    files = [os.path.join(UPLOAD_DIR, p) for p in os.listdir(UPLOAD_DIR)]
    files = [p for p in files if os.path.isfile(p) and os.path.splitext(p)[1].lower() in {".pdf", ".txt", ".md"}]
    if not files:
        return JSONResponse(status_code=400, content={"error": "no files to ingest"})
    n = rp.build_or_update_index(files)
    return {"ingested": n}


@app.post("/chat")
def chat(
    message: str = Form(...),
    objective: Optional[str] = Form(None),
    k: int = Form(5),
):
    if not message:
        return JSONResponse(status_code=400, content={"error": "message required"})

    rp = get_rag()
    lc = get_llm()
    # Avoid slow first-time embedder init when no index is built yet
    has_index = (
        os.path.exists(os.path.join(INDEX_DIR, "faiss.index"))
        and os.path.exists(os.path.join(INDEX_DIR, "meta.json"))
    )
    docs = []
    if has_index:
        try:
            docs = rp.retrieve(message, k=k, objective=objective)
        except Exception:
            docs = []
    ctx = rp.format_context(docs)

    prompt = lc.build_prompt(
        user_message=message,
        objective=objective,
        retrieved_context=ctx,
    )
    answer = lc.generate_text(prompt)

    return {
        "answer": answer,
        "references": [{"source": d.get("source", ""), "text": d.get("text", "")} for d in docs],
    }


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)


