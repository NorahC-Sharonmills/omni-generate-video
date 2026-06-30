import os

import edge_tts
from fastapi import FastAPI
from fastapi.responses import Response
from pydantic import BaseModel, Field


DEFAULT_VOICE = "vi-VN-HoaiMyNeural"
VOICE = os.environ.get("OMNI_TTS_VOICE", DEFAULT_VOICE)

app = FastAPI(title="OmniVoice-compatible TTS server")


class TtsRequest(BaseModel):
    text: str = Field(min_length=1)


@app.get("/")
async def health() -> dict[str, bool]:
    return {"ok": True}


@app.post("/tts", response_class=Response)
async def synthesize(request: TtsRequest) -> Response:
    audio_chunks: list[bytes] = []
    communicate = edge_tts.Communicate(request.text, VOICE)

    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio_chunks.append(chunk["data"])

    return Response(content=b"".join(audio_chunks), media_type="audio/mpeg")
