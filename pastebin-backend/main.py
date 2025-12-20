from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import boto3
import uuid
import time

from starlette.background import P
from jwt_utils import issue_jwt_toke, verify_jwt_token
from Login import Login
# DynamoDB setup
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")  # change region
table_name = "Pastes"
users_table_name = "Users"

# Ensure table exists (create if missing)
# def create_table():
#     existing_tables = boto3.client("dynamodb", region_name="us-east-1").list_tables()["TableNames"]
#     if table_name not in existing_tables:
#         dynamodb.create_table(
#             TableName=table_name,
#             KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
#             AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
#             ProvisionedThroughput={"ReadCapacityUnits": 5, "WriteCapacityUnits": 5},
#         )
#         print("Table created, waiting until active...")
#         boto3.client("dynamodb", region_name="us-east-1").get_waiter("table_exists").wait(TableName=table_name)
# create_table()
table = dynamodb.Table(table_name)
users_table = dynamodb.Table(users_table_name)
# Pydantic model
class Paste(BaseModel):
    title: str
    content: str
    expiresAt: str
    visibility: str
    
    tags: list[str] = []    

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],            # list of allowed origins
    allow_credentials=True,
    allow_methods=["*"],              # or ["GET", "POST"] if you want specific methods
    allow_headers=["*"],              # or specify certain headers
)

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
def create_paste(paste: Paste, request: Request):
    # Require JWT in Authorization header for creating pastes
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

@app.post("/login")
def login(login: Login):
    if login.username is not None and login.password is not None:
        try:
            response = users_table.get_item(Key={"username": login.username})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        
        if "Item" not in response:
            raise HTTPException(status_code=403, detail="Forbidden")
        
        if response["Item"]["password"] == login.password:
            token = issue_jwt_toke(login.username)
            return {"token": token}
    raise HTTPException(status_code=403, detail="Forbidden")

@app.post("/register")
def register(register: Login):
    if register.username is not None and register.password is not None:
        try:
            response = users_table.get_item(Key={"username": register.username})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        
        if "Item" in response:
            raise HTTPException(status_code=409, detail="User already exists")
        
        try:
            users_table.put_item(Item={"username": register.username, "password": register.password})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        token = issue_jwt_toke(register.username)    
        return {"token":token}
    raise HTTPException(status_code=400, detail="Invalid request")

