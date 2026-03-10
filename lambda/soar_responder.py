import json
import os
import boto3

sns = boto3.client("sns")
ec2 = boto3.client("ec2")
TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

def handler(event, context):
    # EventBridge passes a dict, ensure we can log it nicely
    try:
        print("EVENT:", json.dumps(event))
    except Exception:
        pass

    detail_type = event.get("detail-type")
    source = event.get("source")
    detail = event.get("detail", {})

    # 1) Console login fails -> notify
    if source == "aws.signin" and detail_type == "AWS Console Sign In via CloudTrail":
        console_login = detail.get("responseElements", {}).get("ConsoleLogin")
        if console_login == "Failure":
            user = detail.get("userIdentity", {}).get("arn", "unknown")
            ip   = detail.get("sourceIPAddress", "unknown")
            msg  = f"[SOAR] Console login FAILURE\nUser: {user}\nIP: {ip}"
            sns.publish(TopicArn=TOPIC_ARN, Subject="SOAR: Console login failure", Message=msg)
            return {"action": "alerted"}

    # 2) Security group ingress change -> check for risky rule, revert if needed
    if source == "aws.ec2" and detail_type == "AWS API Call via CloudTrail":
        event_name = detail.get("eventName")
        if event_name == "AuthorizeSecurityGroupIngress":
            # CloudTrail requestParameters holds the SG and the permissions
            params = detail.get("requestParameters", {})
            sg_id = params.get("groupId")
            perms = params.get("ipPermissions", [])
            risky = []

            for p in perms or []:
                from_port = p.get("fromPort")
                to_port   = p.get("toPort")
                ip_ranges = [r.get("cidrIp") for r in p.get("ipRanges", []) if r.get("cidrIp")]
                # Flag SSH opened to the world
                if from_port == 22 and to_port == 22 and ("0.0.0.0/0" in ip_ranges):
                    risky.append({"from": from_port, "to": to_port, "cidrs": ip_ranges})

            if risky and sg_id:
                # Revert the risky ingress rule
                try:
                    ec2.revoke_security_group_ingress(
                        GroupId=sg_id,
                        IpPermissions=[{
                            "IpProtocol": "tcp",
                            "FromPort": 22,
                            "ToPort": 22,
                            "IpRanges": [{"CidrIp": "0.0.0.0/0"}]
                        }]
                    )
                    action = f"REVOKED 0.0.0.0/0:22 on {sg_id}"
                except Exception as e:
                    action = f"FAILED to revoke on {sg_id}: {e}"

                msg = f"[SOAR] SG ingress change detected and handled\nSG: {sg_id}\nAction: {action}"
                sns.publish(TopicArn=TOPIC_ARN, Subject="SOAR: SG change", Message=msg)
                return {"action": action}

            # Not risky: alert only
            msg = f"[SOAR] SG ingress modified (not auto-reverted)\nDetails:\n{json.dumps(perms)}"
            sns.publish(TopicArn=TOPIC_ARN, Subject="SOAR: SG change observed", Message=msg)
            return {"action": "observed"}

    # Default: just notify we saw an event
    sns.publish(TopicArn=TOPIC_ARN, Subject="SOAR: Event seen", Message=json.dumps(event)[:2048])
    return {"action": "not_matched"}
