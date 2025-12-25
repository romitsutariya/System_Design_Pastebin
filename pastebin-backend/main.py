from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.responses import PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
import boto3
import uuid
import time
import json

from starlette.background import P
from jwt_utils import issue_jwt_toke, verify_jwt_token
from Paste import Paste
from auth import router as auth_router


# DynamoDB setup
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table_name = "Pastes"
table = dynamodb.Table(table_name)
  
sqs_client = boto3.client("sqs", region_name="us-east-1")

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],            # list of allowed origins
    allow_credentials=True,
    allow_methods=["*"],              # or ["GET", "POST"] if you want specific methods
    allow_headers=["*"],              # or specify certain headers
)

# Mount auth routes
app.include_router(auth_router)

## write functions to conver the expire time from ui into minites user pass 1h, 1d, 1w, 1m, 1y Epoch time value: 1759418109)
def convert_expiration_to_epoch(expiration: str) -> int:
    now = int(time.time())
    mapping = {
        "10min": 10 * 60,
        "1hour": 60 * 60,
        "1day": 24 * 60 * 60,
        "1week": 7 * 24 * 60 * 60,
        "1month": 30 * 24 * 60 * 60,
        "1year": 365 * 24 * 60 * 60,
        "1y": 365 * 24 * 60 * 60,
    }
    seconds = mapping.get(expiration, 5 * 365 * 24 * 60 * 60)  # default to 5 years
    return now + seconds


@app.route("/", methods=["GET", "POST"])
def data(request: Request):
    return PlainTextResponse("Hello World!!!") 

@app.post("/pastes")
def create_paste(paste: Paste, request: Request, background_tasks: BackgroundTasks):
    auth_header = request.headers.get("authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=403, detail="Forbidden")
    token = auth_header.split()[1]
    payload = verify_jwt_token(token)
    print(payload)
    if payload is None:
        raise HTTPException(status_code=403, detail="Forbidden")
    paste_id = str(uuid.uuid4())
    item = {
        "id": paste_id,
        "title": paste.title,
        "content": paste.content,
        "expiresAt": convert_expiration_to_epoch(paste.expiresAt),
        "visibility": paste.visibility,
        "tags": paste.tags,
        "createdBy": payload["user_id"]
    }
    
    try:
        table.put_item(Item=item)
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail=str(e))
    send_message_to_queue(item)
    return {"id": paste_id, "message": "Paste created successfully"}

@app.get("/pastes/{paste_id}")
def get_paste(paste_id: str):
    try:
        response = table.get_item(Key={"id": paste_id})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    if "Item" not in response:
        raise HTTPException(status_code=404, detail="Paste not found")
    
    return response["Item"]


def send_message_to_queue(paste):
    try:
        print("sending message to queue")
        message = {
            "id": paste.get("id"),
            "content": paste.get("content")
        }
        response = sqs_client.send_message(
            QueueUrl="https://sqs.us-east-1.amazonaws.com/186468893492/pastebin-backend-queue",
            MessageBody=json.dumps(message)
        )
        print(f"Message sent! Message ID: {response['MessageId']}")
        return response
    except Exception as e:
        print(f"Error sending message: {e}")
        return None
    


