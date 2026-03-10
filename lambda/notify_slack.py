import os, json, urllib.request

WEBHOOK = os.environ["SLACK_WEBHOOK_URL"]

def handler(event, context):
    msg = f"SOAR Alert: {json.dumps(event)[:2000]}"
    data = json.dumps({"text": msg}).encode("utf-8")
    req = urllib.request.Request(WEBHOOK, data=data, headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req) as r:
        r.read()
    return {"status": "ok"}
