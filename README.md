# PNG Analysis Project

This repository provides the components necessary to:

1. **Build** a containerized application that reads a PNG image and outputs a 2D FFT plot of that image.
2. **Deploy** the application to AWS so that it runs automatically when a PNG file is uploaded to an S3 bucket.
3. **Upload** a local image to the target S3 bucket to trigger processing.

---

## 🛠️ Deployment Instructions

### 🔹 Prerequisites

Before beginning, ensure you have the following installed:

- Python 3.12+
- Docker
- AWS CLI
- Terraform
- pip

Additionally, the IAM user associated with your AWS credentials should have the following policies attached:

#### ✅ AWS Managed Policies

- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonECS_FullAccess`
- `AmazonS3FullAccess`
- `AWSLambda_FullAccess`
- `CloudWatchLogsFullAccess`
- The following custom policy
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:ListAttachedRolePolicies",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:ListRolePolicies",
                "iam:ListInstanceProfilesForRole",
                "iam:PutRolePolicy",
                "iam:AttachRolePolicy",
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::*:role/*"
        }
    ]
}
```

---

### 🔹 Running the Deployment

Navigate to the `scripts/` directory and run:

```bash
./deploy_aws.sh
```

This script will:

1. **Create an ECR repository** to host your Docker image.
2. **Build and push the Docker image** to the ECR repository.
3. **Deploy the AWS infrastructure**, which includes:
   - An S3 bucket
   - A Lambda function triggered by image uploads to the bucket
   - An on-demand ECS Fargate task to run the container

> ⚠️ **Important:** When deployment is complete, the script will print the S3 bucket name to your console.  
**Save this name** — you will use it to upload images and trigger processing.

Example:
```
my-images-0f2837bf-ef72-901e-94f8-2dbed0a4d701
```


---

## 📸 Using the Deployed Service

After successful deployment, you're ready to analyze images via cloud infrastructure.

### Step 1: Create and Activate a Virtual Environment

From the project root:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

> This installs `boto3` and any other dependencies for the uploader script.

---

### Step 2: Prepare the Image

Place the image you want to analyze in the `images/` subfolder.

A sample image (`lena.png`) is already provided for testing.

---

### Step 3: Upload the Image

Run the upload script from the root of the project:

```bash
python scripts/upload_image.py <path-to-image> <s3-bucket-name>
```

Example:

```bash
python scripts/upload_image.py images/lena.png my-images-0f2837bf-ef72-901e-94f8-2dbed0a4d701
```

This will upload the image to your S3 bucket and trigger the processing pipeline.

---

### Step 4: View the Output

Once the ECS task finishes, your processed image will appear in the same S3 bucket under:

```
/outputs/
```

It will be named in the format:

```
<original-image-name>-<timestamp>-fft-plot.png
```

You can download and view this file directly from the AWS S3 Console.

---

## 🧹 Troubleshooting

If you encounter issues during deployment:

- Ensure IAM permissions are correctly configured
- Confirm that all tools (`docker`, `aws`, `terraform`, etc.) are installed and accessible via your terminal
- Check the AWS CloudWatch logs for Lambda or ECS task errors