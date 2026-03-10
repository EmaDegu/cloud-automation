import boto3, os, time

ec2 = boto3.client("ec2")

def handler(event, context):
    # Stop instances with tag AutoStop=true that are running
    resp = ec2.describe_instances(
        Filters=[
            {"Name":"instance-state-name","Values":["running"]},
            {"Name":"tag:AutoStop","Values":["true"]}
        ]
    )
    ids=[]
    for r in resp["Reservations"]:
        for i in r["Instances"]:
            ids.append(i["InstanceId"])
    if ids:
        ec2.stop_instances(InstanceIds=ids)
    return {"stopped": ids}
