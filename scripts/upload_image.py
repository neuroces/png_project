import argparse
import os
from datetime import UTC, datetime

import boto3


def upload_file_with_timestamp(local_path: str, bucket_name: str, s3_prefix: str):
    """
    Upload a file to S3 with a timestamp in the filename.
    """
    s3 = boto3.client("s3")
    filename = os.path.basename(local_path)
    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S")
    filename_parts = os.path.splitext(filename)
    new_filename = f"{filename_parts[0]}_{timestamp}{filename_parts[1]}"
    s3_key = f"{s3_prefix}/{new_filename}"

    s3.upload_file(local_path, bucket_name, s3_key)
    print(f"Uploaded to s3://{bucket_name}/{s3_key}")

if __name__ == "__main__":
    # parse arguments
    parser = argparse.ArgumentParser(description="Upload an image to S3")
    parser.add_argument("local_image_path", type=str, help="Path to the local image file")
    parser.add_argument("bucket_name", type=str, help="Name of the S3 bucket")
    args = parser.parse_args()
    # run function
    upload_file_with_timestamp(args.local_image_path, args.bucket_name, s3_prefix="inputs")
