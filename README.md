# Personal Finance MCP Deployment

This Terraform configuration deploys the resources required to process bank statement files.

## Building the ECS Image

1. Navigate to the `ecs/` directory.
2. Run `./build.sh` to build and push the Docker image to the created ECR repository.

Ensure you are authenticated with AWS CLI before running the script.

## Deploying

After pushing the image, run `terraform init` and `terraform apply` to create the infrastructure. Uploading a file to the statements S3 bucket will trigger the Lambda which starts an ECS task. The task will shut itself down when processing is complete.

## Testing the API Gateway

After deploying, you can retrieve a specific transaction using the API Gateway. Obtain the `transactions_api_url` output from Terraform and run:

```bash
curl "${transactions_api_url}/transaction?transaction_id=<TRANSACTION_ID>"
```

A helper script `get_transaction.sh` is included to simplify this:

```bash
./get_transaction.sh <TRANSACTION_ID>
```

Replace `<TRANSACTION_ID>` with the ID of the record you want to fetch.

To list all transactions, use the `/transactions` endpoint:

```bash
curl "${transactions_api_url}/transactions"
```

A helper script `list_transactions.sh` simplifies this:

```bash
./list_transactions.sh
```
