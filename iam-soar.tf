resource "aws_iam_role" "soar_lambda_role" {
  name = "soar-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Inline policy: allow Lambda to read events, modify SGs, manage EC2 power, publish to SNS, and write logs
resource "aws_iam_role_policy" "soar_inline" {
  name = "soar-inline"
  role = aws_iam_role.soar_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { # logs
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      { # EC2 mutate for isolation/stop
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:ModifyInstanceAttribute",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateTags",
          "ec2:ReplaceNetworkAclAssociation",
          "ec2:DescribeNetworkAcls",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:StopInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules"
        ],
        Resource = "*"
      },
      { # SNS alerting
        Effect   = "Allow",
        Action   = ["sns:Publish"],
        Resource = "*"
      }
    ]
  })
}
