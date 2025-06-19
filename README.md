# Personal Finance MCP Deployment

This Terraform configuration deploys the resources required to process bank statement files.

## Building the ECS Image

1. Navigate to the `ecs/` directory.
2. Run `./build.sh` to build and push the Docker image to the created ECR repository.

Ensure you are authenticated with AWS CLI before running the script.

## Deploying

After pushing the image, run `terraform init` and `terraform apply` to create the infrastructure. Uploading a file to the statements S3 bucket will trigger the Lambda which starts an ECS task. The task will shut itself down when processing is complete.

## Frontend Dashboard

The `frontend` directory contains a simple Svelte dashboard that fetches
transaction data from the API and displays expenses by category in a bar chart.

To run the dashboard locally:

```bash
cd frontend
npm install
npm run dev
```

Then open <http://localhost:5173> in your browser.

