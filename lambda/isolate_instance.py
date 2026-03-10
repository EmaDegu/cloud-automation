import os, json, boto3

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

QUARANTINE_SG_ID = os.environ["QUARANTINE_SG_ID"]
SNS_ARN = os.environ["SNS_ARN"]

def handler(event, context):
    # Expect event to include instance_id
    print("Event:", json.dumps(event))
    instance_id = event.get("detail", {}).get("instance-id") or event.get("instance_id")
    if not instance_id:
        raise Exception("No instance_id in event")

    # Get primary ENI
    resp = ec2.describe_instances(InstanceIds=[instance_id])
    nis = resp["Reservations"][0]["Instances"][0]["NetworkInterfaces"]
    if not nis:
        raise Exception("No ENIs")
    eni_id = nis[0]["NetworkInterfaceId"]

    # Replace SGs on the ENI with quarantine SG only
    ec2.modify_network_interface_attribute(
        NetworkInterfaceId=eni_id,
        Groups=[QUARANTINE_SG_ID]
    )

    sns.publish(
        TopicArn=SNS_ARN,
        Subject=f"[SOAR] Instance isolated: {instance_id}",
        Message=f"Instance {instance_id} moved to quarantine SG {QUARANTINE_SG_ID}."
    )
    return {"status": "ok", "instance_id": instance_id}
