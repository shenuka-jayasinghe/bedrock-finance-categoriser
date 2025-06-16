# lambda_function.py
import json
import boto3
import pandas as pd
import hashlib
import os
from datetime import datetime
from typing import List, Dict, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
bedrock_client = boto3.client('bedrock-runtime')

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
AWS_REGION = os.environ['AWS_REGION']

# Get DynamoDB table
table = dynamodb.Table(DYNAMODB_TABLE)

CATEGORIES = [
    "Groceries (Tesco, Sainsbury's, ASDA, Morrisons, Aldi, Lidl, food shopping)",
    "Dining (restaurants, takeaways, cafes, pubs, food delivery)",
    "Shopping (clothes, electronics, general retail, Amazon, eBay, non-grocery)",
    "Subscriptions (Netflix, Spotify, gym memberships, software, magazines)",
    "Utilities (gas, electricity, water, council tax, broadband, phone)",
    "Transport (fuel, parking, public transport, car maintenance, insurance)",
    "Healthcare (pharmacy, dental, medical, health insurance)",
    "Insurance (car, home, life, travel insurance)",
    "Banking (fees, charges, interest, account maintenance)",
    "Income (salary, benefits, refunds, cashback)",
    "Transfers (personal transfers, family payments)",
    "Entertainment (cinema, streaming, games, events, hobbies)",
    "Home (furniture, appliances, DIY, home improvement)",
    "Personal (haircut, beauty, clothing, personal care)",
    "Education (books, courses, training, school fees)",
    "Travel (holidays, hotels, flights, travel insurance)"
]

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Extract S3 event information
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = event['Records'][0]['s3']['object']['key']
        
        logger.info(f"Processing file: {object_key} from bucket: {bucket_name}")
        
        # Download and parse CSV
        transactions = download_and_parse_csv(bucket_name, object_key)
        
        # Check what needs to be processed
        unprocessed_transactions = get_unprocessed_transactions(transactions, object_key)
        
        if not unprocessed_transactions:
            logger.info("No new transactions to process")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No new transactions to process'})
            }
        
        logger.info(f"Found {len(unprocessed_transactions)} transactions to classify")
        
        # Classify transactions using Bedrock
        classified_transactions = classify_transactions_batch(unprocessed_transactions)
        
        # Update DynamoDB
        update_dynamodb_batch(classified_transactions, object_key)
        
        logger.info(f"Successfully processed {len(classified_transactions)} transactions")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed {len(classified_transactions)} transactions',
                'file': object_key
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing transactions: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def download_and_parse_csv(bucket_name: str, object_key: str) -> List[Dict]:
    """Download CSV from S3 and parse into transactions"""
    try:
        # Download file from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        csv_content = response['Body'].read()
        
        # Parse CSV using pandas
        df = pd.read_csv(pd.io.common.BytesIO(csv_content))
        
        # Convert to list of dictionaries
        transactions = []
        for _, row in df.iterrows():
            # Create unique transaction ID
            transaction_data = f"{row['Transaction Date']}-{row['Transaction Description']}-{row.get('Debit Amount', row.get('Credit Amount', 0))}"
            transaction_id = hashlib.md5(transaction_data.encode()).hexdigest()
            
            transaction = {
                'transaction_id': transaction_id,
                'date': row['Transaction Date'],
                'type': row['Transaction Type'],
                'description': row['Transaction Description'],
                'debit_amount': row.get('Debit Amount', ''),
                'credit_amount': row.get('Credit Amount', ''),
                'balance': row.get('Balance', ''),
                'sort_code': row.get('Sort Code', ''),
                'account_number': row.get('Account Number', '')
            }
            transactions.append(transaction)
            
        return transactions
        
    except Exception as e:
        logger.error(f"Error downloading/parsing CSV: {str(e)}")
        raise

def get_unprocessed_transactions(transactions: List[Dict], file_name: str) -> List[Dict]:
    """Check DynamoDB for already processed transactions"""
    unprocessed = []
    
    try:
        for transaction in transactions:
            # Check if transaction exists and is processed
            response = table.get_item(
                Key={'transaction_id': transaction['transaction_id']}
            )
            
            if 'Item' not in response:
                # Transaction doesn't exist, add to unprocessed
                unprocessed.append(transaction)
            elif response['Item'].get('processed') != 'true':
                # Transaction exists but not processed
                unprocessed.append(transaction)
                
        return unprocessed
        
    except Exception as e:
        logger.error(f"Error checking processed transactions: {str(e)}")
        raise

def classify_transactions_batch(transactions: List[Dict]) -> List[Dict]:
    """Classify transactions using Claude Haiku in batch"""
    try:
        # Prepare transactions for prompt
        transaction_list = []
        for txn in transactions:
            amount = txn['debit_amount'] if txn['debit_amount'] else f"+{txn['credit_amount']}"
            transaction_list.append(f"{txn['date']} | {txn['description']} | {amount}")
        
        # Create prompt
        prompt = f"""You are an expert financial analyst. Classify each transaction into the most appropriate category.

CATEGORIES:
{chr(10).join(f"• {cat}" for cat in CATEGORIES)}

TRANSACTIONS TO CLASSIFY:
{chr(10).join(transaction_list)}

OUTPUT FORMAT:
Return ONLY a JSON array with this exact structure:
[
  {{
    "date": "DD/MM/YYYY",
    "description": "Transaction Description",
    "amount": "Amount",
    "category": "Category Name"
  }}
]

Rules:
- Use exact category names from the list above
- Match the date and description exactly as provided
- Be consistent with similar merchants
- If uncertain, choose the most logical category"""

        # Call Bedrock
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 4000,
            "temperature": 0.1,
            "top_p": 0.9,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }
        
        response = bedrock_client.invoke_model(
            modelId="anthropic.claude-3-haiku-20240307-v1:0",
            body=json.dumps(body)
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        classified_data = json.loads(response_body['content'][0]['text'])
        
        # Merge classifications with original transaction data
        classified_transactions = []
        for i, txn in enumerate(transactions):
            if i < len(classified_data):
                txn['category'] = classified_data[i]['category']
                txn['classified_at'] = datetime.utcnow().isoformat()
            else:
                txn['category'] = "Uncategorized"
                txn['classified_at'] = datetime.utcnow().isoformat()
            
            classified_transactions.append(txn)
        
        return classified_transactions
        
    except Exception as e:
        logger.error(f"Error classifying transactions: {str(e)}")
        # Return transactions with default category if classification fails
        for txn in transactions:
            txn['category'] = "Uncategorized"
            txn['classified_at'] = datetime.utcnow().isoformat()
        return transactions

def update_dynamodb_batch(transactions: List[Dict], file_name: str):
    """Update DynamoDB with classified transactions in batches"""
    try:
        # DynamoDB batch write limit is 25 items
        batch_size = 25
        
        for i in range(0, len(transactions), batch_size):
            batch = transactions[i:i + batch_size]
            
            with table.batch_writer() as batch_writer:
                for txn in batch:
                    item = {
                        'transaction_id': txn['transaction_id'],
                        'file_name': file_name,
                        'date': txn['date'],
                        'type': txn['type'],
                        'description': txn['description'],
                        'debit_amount': txn['debit_amount'],
                        'credit_amount': txn['credit_amount'],
                        'balance': txn['balance'],
                        'category': txn['category'],
                        'processed': 'true',
                        'classified_at': txn['classified_at'],
                        'created_at': datetime.utcnow().isoformat()
                    }
                    batch_writer.put_item(Item=item)
            
            logger.info(f"Processed batch {i//batch_size + 1}/{(len(transactions) + batch_size - 1)//batch_size}")
        
    except Exception as e:
        logger.error(f"Error updating DynamoDB: {str(e)}")
        raise