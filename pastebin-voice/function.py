import boto3
import os
import time
import json

region = os.getenv('AWS_REGION', 'us-east-1')
polly_client = boto3.client('polly', region_name=region)
s3_client = boto3.client('s3', region_name=region)

def synthesize_and_upload(text, bucket, key, voice='Joanna', engine='neural'):
    response = polly_client.synthesize_speech(
        VoiceId=voice,
        OutputFormat='mp3',
        Text=text,
        Engine=engine
    )
    if 'AudioStream' not in response:
        raise RuntimeError('AudioStream missing in Polly response')
    audio_bytes = response['AudioStream'].read()
    s3_client.put_object(Bucket=bucket, Key=key, Body=audio_bytes, ContentType='audio/mpeg')
    return f"s3://{bucket}/{key}"

def handler(event, context):
    bucket = os.getenv('S3_BUCKET')
    voice = os.getenv('POLLY_VOICE', 'Joanna')
    engine = os.getenv('POLLY_ENGINE', 'neural')
    if not bucket:
        raise RuntimeError('S3_BUCKET environment variable is required')

    records = event.get('Records', []) if isinstance(event, dict) else []
    results = []
    for record in records:
        raw_body = record.get('body', '') if isinstance(record, dict) else ''
        try:
            body = json.loads(raw_body) if raw_body else {}
        except Exception:
            body = {}
        content = body.get('content', '')
        paste_id = body.get('id')
        if not content:
            continue
        if not paste_id:
            paste_id = str(int(time.time() * 1000))
        object_key = f"polly/{paste_id}.mp3"
        s3_uri = synthesize_and_upload(content, bucket, object_key, voice=voice, engine=engine)
        results.append({'message_id': record.get('messageId'), 'paste_id': paste_id, 's3_uri': s3_uri})

    return {
        'processed': len(results),
        'items': results
    }
