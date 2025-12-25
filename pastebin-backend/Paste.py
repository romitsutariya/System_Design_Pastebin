from pydantic import BaseModel
class Paste(BaseModel):
    title: str
    content: str
    expiresAt: str
    visibility: str
    
    tags: list[str] = []  