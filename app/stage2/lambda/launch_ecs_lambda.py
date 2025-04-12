import os

import boto3

ecs = boto3.client("ecs")


def lambda_handler(event: dict, context: dict) -> dict:
    """
    Lambda function to launch an ECS task to analyze an image.
    """
    # Get the bucket and key from the event
    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key = record["s3"]["object"]["key"]

    # Construct the image path
    image_path = f"s3://{bucket}/{key}"
    print(f"Image path: {image_path}")

    try:
        # Launch the ECS task
        ecs.run_task(
            cluster=os.environ["ECS_CLUSTER"],
            launchType="FARGATE",
            taskDefinition=os.environ["TASK_DEFINITION"],
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": [os.environ["SUBNET_ID"]],
                    "assignPublicIp": "ENABLED",
                }
            },
            overrides={
                "containerOverrides": [
                    {
                        "name": "fft-analyzer",
                        "environment": [
                            {"name": "INPUT_BUCKET", "value": bucket},
                            {"name": "INPUT_KEY", "value": key},
                        ],
                    }
                ]
            },
        )
        print("Task submitted successfully")
    except Exception as e:
        print(f"Error: {e}")
        raise e
