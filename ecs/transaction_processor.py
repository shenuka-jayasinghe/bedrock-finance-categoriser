#!/usr/bin/env python3
import json
import boto3
import csv
import hashlib
import os
import re
import time
import sys
from datetime import datetime
from typing import List, Dict, Any
import logging
import io

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
bedrock_client = boto3.client('bedrock-runtime')
ecs_client = boto3.client('ecs')

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
AWS_REGION = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
S3_BUCKET = os.environ.get('S3_BUCKET')
S3_KEY = os.environ.get('S3_KEY')

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

def get_task_arn():
    """Get the current ECS task ARN from metadata endpoint"""
    try:
        import urllib.request
        metadata_uri = os.environ.get('ECS_CONTAINER_METADATA_URI_V4')
        if metadata_uri:
            task_metadata_uri = f"{metadata_uri}/task"
            with urllib.request.urlopen(task_metadata_uri) as response:
                task_metadata = json.loads(response.read().decode())
                return task_metadata.get('TaskARN')
    except Exception as e:
        logger.warning(f"Could not get task ARN: {e}")
    return None

def stop_current_task():
    """Stop the current ECS task"""
    try:
        task_arn = get_task_arn()
        if task_arn:
            cluster_name = task_arn.split('/')[1]  # Extract cluster name from ARN
            logger.info(f"Stopping task: {task_arn}")
            ecs_client.stop_task(
                cluster=cluster_name,
                task=task_arn,
                reason='Processing completed'
            )
            logger.info("Task stop request sent")
        else:
            logger.warning("Could not determine task ARN, cannot stop task")
    except Exception as e:
        logger.error(f"Error stopping task: {e}")

def main():
    """Main function to process transactions"""
    try:
        if not S3_BUCKET or not S3_KEY:
            logger.error("S3_BUCKET and S3_KEY environment variables are required")
            sys.exit(1)
        
        logger.info(f"Processing file: {S3_KEY} from bucket: {S3_BUCKET}")
        
        # Download and parse CSV
        transactions = download_and_parse_csv(S3_BUCKET, S3_KEY)
        
        # Check what needs to be processed
        unprocessed_transactions = get_unprocessed_transactions(transactions, S3_KEY)
        
        if not unprocessed_transactions:
            logger.info("No new transactions to process")
            return
        
        logger.info(f"Found {len(unprocessed_transactions)} transactions to classify")
        
        # Classify transactions using Bedrock
        classified_transactions = classify_transactions_batch(unprocessed_transactions)
        
        # Update DynamoDB
        update_dynamodb_batch(classified_transactions, S3_KEY)
        
        logger.info(f"Successfully processed {len(classified_transactions)} transactions")
        
    except Exception as e:
        logger.error(f"Error processing transactions: {str(e)}")
        sys.exit(1)
    finally:
        # Always try to stop the task when done
        stop_current_task()

def download_and_parse_csv(bucket_name: str, object_key: str) -> List[Dict]:
    """Download CSV from S3 and parse into transactions"""
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        csv_content = response['Body'].read().decode('utf-8')
        
        csv_reader = csv.DictReader(io.StringIO(csv_content))
        transactions = []
        
        for row_index, row in enumerate(csv_reader):
            # Create more unique transaction ID including row index and more fields
            debit_amt = row.get('Debit Amount', '').strip()
            credit_amt = row.get('Credit Amount', '').strip()
            balance = row.get('Balance', '').strip()
            
            # Include more fields in hash to ensure uniqueness
            hash_input = f"{row['Transaction Date']}-{row['Transaction Description']}-{debit_amt}-{credit_amt}-{balance}-{row_index}"
            transaction_id = hashlib.md5(hash_input.encode()).hexdigest()
            
            transaction = {
                'transaction_id': transaction_id,
                'date': row['Transaction Date'],
                'description': row['Transaction Description'],
                'debit_amount': debit_amt,
                'credit_amount': credit_amt,
                'balance': balance,
                'sort_code': row.get('Sort Code', ''),
                'account_number': row.get('Account Number', '')
            }
            transactions.append(transaction)
            
        logger.info(f"Parsed {len(transactions)} transactions from CSV")
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

def extract_json_from_response(text: str) -> str:
    """Extract JSON array from response text, handling various formats"""
    # Remove markdown code blocks if present
    text = re.sub(r'```json\s*', '', text)
    text = re.sub(r'```\s*$', '', text)
    
    # Find JSON array - look for [ ... ]
    json_match = re.search(r'\[.*\]', text, re.DOTALL)
    if json_match:
        return json_match.group(0)
    
    # If no array found, return original text
    return text

def fix_json_formatting(json_str: str) -> str:
    """Fix common JSON formatting issues"""
    # Replace single quotes with double quotes
    json_str = re.sub(r"'", '"', json_str)
    
    # Fix unquoted keys (basic pattern)
    json_str = re.sub(r'(\w+):', r'"\1":', json_str)
    
    # Remove trailing commas
    json_str = re.sub(r',\s*}', '}', json_str)
    json_str = re.sub(r',\s*]', ']', json_str)
    
    return json_str

def classify_transactions_batch(transactions: List[Dict]) -> List[Dict]:
    """Classify transactions using Claude Haiku in batch with robust JSON parsing"""
    try:
        # Process in smaller batches to reduce rate limiting
        batch_size = 5  # Reduced from 10
        all_classified = []
        
        for i in range(0, len(transactions), batch_size):
            batch = transactions[i:i + batch_size]
            
            # Add delay between batches to avoid rate limiting
            if i > 0:
                time.sleep(1)  # 1 second delay between batches
            
            # Prepare transactions for prompt
            transaction_list = []
            for txn in batch:
                amount = txn['debit_amount'] if txn['debit_amount'] else f"+{txn['credit_amount']}"
                transaction_list.append(f"{txn['date']} | {txn['description']} | {amount}")
            
            # Create prompt with short category names for easier matching
            prompt = f"""Classify these UK bank transactions into categories. Return ONLY valid JSON.

CATEGORIES (use these exact names):
• Groceries
• Dining  
• Shopping
• Subscriptions
• Utilities
• Transport
• Healthcare
• Insurance
• Banking
• Income
• Transfers
• Entertainment
• Home
• Personal
• Education
• Travel
• Housing

TRANSACTIONS:
{chr(10).join(transaction_list)}

Return strictly valid JSON array (no explanations, no markdown):
[
  {{
    "date": "DD/MM/YYYY",
    "description": "Transaction Description", 
    "amount": "Amount",
    "category": "Category Name"
  }}
]

Use double quotes only. No trailing commas. Use exact category names from list above.
Examples:
- Tesco, Sainsbury's, ASDA → "Groceries"
- McDonald's, Deliveroo, restaurants → "Dining"
- Amazon, clothes, electronics → "Shopping"
- Netflix, Spotify, gym → "Subscriptions"
- Gas, electricity, council tax → "Utilities"
- Petrol, parking, bus tickets → "Transport"
- Salary, wages, refunds → "Income"
- Bank transfers, family payments → "Transfers"
- Cinema, games, events → "Entertainment"
- Furniture, DIY, home improvement → "Home"
- Haircut, beauty, clothing → "Personal"
- Pharmacy, dental, medical → "Healthcare"
- Car insurance, home insurance → "Insurance"
- Bank fees, charges → "Banking"
- Books, courses, training → "Education"
- Hotels, flights, holidays → "Travel"
- Rent, Mortgage → "Housing"
"""

            # Call Bedrock with retry logic and exponential backoff
            classified_batch = None
            max_retries = 3
            base_delay = 2  # Start with 2 seconds
            
            for attempt in range(max_retries):
                try:
                    body = {
                        "anthropic_version": "bedrock-2023-05-31",
                        "max_tokens": 1500,  # Reduced from 2000
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
                    raw_response = response_body['content'][0]['text']
                    
                    logger.info(f"Raw response: {raw_response[:500]}...")  # Log first 500 chars
                    
                    # Extract and fix JSON
                    json_text = extract_json_from_response(raw_response)
                    fixed_json = fix_json_formatting(json_text)
                    
                    logger.info(f"Fixed JSON: {fixed_json[:500]}...")  # Log first 500 chars
                    
                    # Parse JSON
                    classified_batch = json.loads(fixed_json)
                    break
                    
                except json.JSONDecodeError as e:
                    logger.warning(f"JSON parsing attempt {attempt + 1} failed: {str(e)}")
                    if attempt == max_retries - 1:
                        logger.error("All JSON parsing attempts failed, using fallback")
                        classified_batch = None
                except Exception as e:
                    error_msg = str(e)
                    logger.error(f"Bedrock call attempt {attempt + 1} failed: {error_msg}")
                    
                    # Handle rate limiting with exponential backoff
                    if "Too many tokens" in error_msg or "throttled" in error_msg.lower():
                        if attempt < max_retries - 1:
                            delay = base_delay * (2 ** attempt)  # Exponential backoff
                            logger.info(f"Rate limited, waiting {delay} seconds before retry...")
                            time.sleep(delay)
                            continue
                    
                    if attempt == max_retries - 1:
                        raise
            
            # Merge classifications with original transaction data
            for j, txn in enumerate(batch):
                if classified_batch and j < len(classified_batch):
                    # Get the category from Claude's response
                    raw_category = classified_batch[j].get('category', 'Uncategorized')
                    
                    # Create a mapping of short names to full category names
                    # Use exact strings from CATEGORIES list
                    category_mapping = {
                        'Groceries': CATEGORIES[0],  # "Groceries (Tesco, Sainsbury's, ASDA, Morrisons, Aldi, Lidl, food shopping)"
                        'Dining': CATEGORIES[1],     # "Dining (restaurants, takeaways, cafes, pubs, food delivery)"
                        'Shopping': CATEGORIES[2],   # "Shopping (clothes, electronics, general retail, Amazon, eBay, non-grocery)"
                        'Subscriptions': CATEGORIES[3], # "Subscriptions (Netflix, Spotify, gym memberships, software, magazines)"
                        'Utilities': CATEGORIES[4],  # "Utilities (gas, electricity, water, council tax, broadband, phone)"
                        'Transport': CATEGORIES[5],  # "Transport (fuel, parking, public transport, car maintenance, insurance)"
                        'Healthcare': CATEGORIES[6], # "Healthcare (pharmacy, dental, medical, health insurance)"
                        'Insurance': CATEGORIES[7],  # "Insurance (car, home, life, travel insurance)"
                        'Banking': CATEGORIES[8],    # "Banking (fees, charges, interest, account maintenance)"
                        'Income': CATEGORIES[9],     # "Income (salary, benefits, refunds, cashback)"
                        'Transfers': CATEGORIES[10], # "Transfers (personal transfers, family payments)"
                        'Entertainment': CATEGORIES[11], # "Entertainment (cinema, streaming, games, events, hobbies)"
                        'Home': CATEGORIES[12],      # "Home (furniture, appliances, DIY, home improvement)"
                        'Personal': CATEGORIES[13],  # "Personal (haircut, beauty, clothing, personal care)"
                        'Education': CATEGORIES[14], # "Education (books, courses, training, school fees)"
                        'Travel': CATEGORIES[15],     # "Travel (holidays, hotels, flights, travel insurance)"
                        'Housing': CATEGORIES[16], # "Housing (Rent, mortgage)"
                    }
                    
                    # Map short category to full category, or check if it's already a full category
                    if raw_category in category_mapping:
                        category = category_mapping[raw_category]
                        logger.info(f"Mapped '{raw_category}' to '{category}'")
                    elif raw_category in CATEGORIES:
                        category = raw_category
                        logger.info(f"Found exact match for '{raw_category}'")
                    else:
                        logger.warning(f"Unknown category '{raw_category}', available mappings: {list(category_mapping.keys())}")
                        category = 'Uncategorized'
                    
                    txn['category'] = category
                else:
                    txn['category'] = 'Uncategorized'
                
                txn['classified_at'] = datetime.utcnow().isoformat()
                all_classified.append(txn)
            
            logger.info(f"Classified batch {i//batch_size + 1}/{(len(transactions) + batch_size - 1)//batch_size}")
        
        return all_classified
        
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
        # Remove duplicates based on transaction_id
        unique_transactions = {}
        for txn in transactions:
            transaction_id = txn['transaction_id']
            if transaction_id not in unique_transactions:
                unique_transactions[transaction_id] = txn
            else:
                logger.warning(f"Duplicate transaction_id found: {transaction_id}, keeping first occurrence")
        
        unique_txn_list = list(unique_transactions.values())
        logger.info(f"Processing {len(unique_txn_list)} unique transactions (removed {len(transactions) - len(unique_txn_list)} duplicates)")
        
        # DynamoDB batch write limit is 25 items
        batch_size = 25
        
        for i in range(0, len(unique_txn_list), batch_size):
            batch = unique_txn_list[i:i + batch_size]
            
            # Further deduplication within batch to be extra safe
            batch_items = {}
            for txn in batch:
                transaction_id = txn['transaction_id']
                if transaction_id not in batch_items:
                    item = {
                        'transaction_id': transaction_id,
                        'file_name': file_name,
                        'date': txn['date'],
                        'description': txn['description'],
                        'debit_amount': txn['debit_amount'],
                        'credit_amount': txn['credit_amount'],
                        'balance': txn['balance'],
                        'category': txn['category'],
                        'processed': 'true',
                        'classified_at': txn['classified_at'],
                        'created_at': datetime.utcnow().isoformat()
                    }
                    
                    # Add optional fields if they exist
                    if 'sort_code' in txn:
                        item['sort_code'] = txn['sort_code']
                    if 'account_number' in txn:
                        item['account_number'] = txn['account_number']
                    
                    batch_items[transaction_id] = item
            
            # Write unique items in this batch
            with table.batch_writer() as batch_writer:
                for item in batch_items.values():
                    batch_writer.put_item(Item=item)
            
            logger.info(f"Updated DynamoDB batch {i//batch_size + 1}/{(len(unique_txn_list) + batch_size - 1)//batch_size} with {len(batch_items)} items")
        
    except Exception as e:
        logger.error(f"Error updating DynamoDB: {str(e)}")
        raise

if __name__ == "__main__":
    main()