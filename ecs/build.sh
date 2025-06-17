#!/bin/bash

# Exit on any error
set -e

# Configuration - Update these values
AWS_REGION="eu-west-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_NAME="transaction-processor"
IMAGE_TAG="latest"

# Full ECR repository URI
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"

echo "Building and pushing Docker image to ECR..."
echo "Repository: ${ECR_URI}"

# Get login token and login to ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

# Build the Docker image
echo "Building Docker image..."
docker build -t ${ECR_REPOSITORY_NAME}:${IMAGE_TAG} .

# Tag the image for ECR
echo "Tagging image for ECR..."
docker tag ${ECR_REPOSITORY_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}

# Push the image to ECR
echo "Pushing image to ECR..."
docker push ${ECR_URI}:${IMAGE_TAG}

echo "Successfully pushed image to ECR: ${ECR_URI}:${IMAGE_TAG}"

# Update ECS service to use the new image (optional)
echo "Image is ready. You can now deploy using Terraform or update your ECS service."
echo ""
echo "ECR Repository URL: ${ECR_URI}"
echo "Image Tag: ${IMAGE_TAG}"