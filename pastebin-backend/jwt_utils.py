import jwt
import datetime

SECRET_KEY="pastebin"

def issue_jwt_toke(user_id)->str:
    payload={
        "user_id":user_id,
        "exp":datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=30),
        "iat": datetime.datetime.now(datetime.timezone.utc)
    }
    return jwt.encode(payload,SECRET_KEY,algorithm="HS256")

def verify_jwt_token(token)->dict:
    try:
        payload=jwt.decode(token,SECRET_KEY,algorithms=["HS256"],options={"verify_exp":True})
        return payload
    except:
        return None
