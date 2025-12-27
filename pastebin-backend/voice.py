from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
import boto3
import os

# Configure S3
_region = os.getenv("AWS_REGION", "us-east-1")
_bucket = os.getenv("VOICE_BUCKET", "pastebin-voice-output")
_s3 = boto3.client("s3", region_name=_region)

router = APIRouter()

@router.get("/pastes/{paste_id}/voice")
def get_paste_voice(paste_id: str):
    """
    Stream the generated voice note MP3 for a paste from S3.
    Object key convention: polly/{paste_id}.mp3
    """
    key = f"polly/{paste_id}.mp3"
    try:
        obj = _s3.get_object(Bucket=_bucket, Key=key)
    except _s3.exceptions.NoSuchKey:
        raise HTTPException(status_code=404, detail="Voice note not found")
    except Exception as e:
        msg = str(e)
        if "NoSuchKey" in msg or "404" in msg:
            raise HTTPException(status_code=404, detail="Voice note not found")
        raise HTTPException(status_code=500, detail=str(e))

    body = obj.get("Body")
    if body is None:
        raise HTTPException(status_code=404, detail="Voice note not found")

    headers = {
        "Content-Type": "audio/mpeg",
        "Content-Disposition": f"inline; filename=\"{paste_id}.mp3\"",
    }
    length = obj.get("ContentLength")
    if isinstance(length, int):
        headers["Content-Length"] = str(length)

    return StreamingResponse(body, media_type="audio/mpeg", headers=headers)
