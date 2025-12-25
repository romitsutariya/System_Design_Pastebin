from fastapi import APIRouter, HTTPException
import boto3
from jwt_utils import issue_jwt_toke
from Login import Login

# DynamoDB Users table setup
_dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
_users_table = _dynamodb.Table("Users")

router = APIRouter()

@router.post("/login")
def login(login: Login):
    if login.username is not None and login.password is not None:
        try:
            response = _users_table.get_item(Key={"username": login.username})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        if "Item" not in response:
            raise HTTPException(status_code=403, detail="Forbidden")
        if response["Item"]["password"] == login.password:
            token = issue_jwt_toke(login.username)
            return {"token": token}
    raise HTTPException(status_code=403, detail="Forbidden")

@router.post("/register")
def register(register: Login):
    if register.username is not None and register.password is not None:
        try:
            response = _users_table.get_item(Key={"username": register.username})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        if "Item" in response:
            raise HTTPException(status_code=409, detail="User already exists")
        try:
            _users_table.put_item(Item={"username": register.username, "password": register.password})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        token = issue_jwt_toke(register.username)
        return {"token": token}
    raise HTTPException(status_code=400, detail="Invalid request")
