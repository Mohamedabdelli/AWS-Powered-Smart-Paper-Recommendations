import json
import boto3
import requests
import urllib.parse

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table_dynamo_name = 'articles'
customer_table = dynamodb.Table(table_dynamo_name)

def insert_customer_record(customer_data):
    response = customer_table.put_item(Item=customer_data)
    return response

def get_from_id(id, table_name):
    customer_table = dynamodb.Table(table_name)
    response = customer_table.scan(
        FilterExpression=boto3.dynamodb.conditions.Attr('id').eq(id)
    )
    if 'Items' in response and len(response['Items']) > 0:
        return response['Items']
    else:
        return None

def extract_papers(query: str):
    query = urllib.parse.quote(query)
    url = f"https://paperswithcode.com/api/v1/papers/?q={query}"
    response = requests.get(url)
    response = response.json()
    count = response["count"]
    results = response["results"]

    num_pages = count // 50
    for page in range(2, num_pages + 1):
        url = f"https://paperswithcode.com/api/v1/papers/?page={page}&q={query}"
        response = requests.get(url)
        response = response.json()
        results += response["results"]
    return results

def lambda_handler(event, context):
    query = event["query"]
    results = extract_papers(query)
    bucket_name = "sfcr-projet"

    for idx, result in enumerate(results):
        id = result['url_abs'].split("/")[-1]
        existing_record = get_from_id(id, table_dynamo_name)
        
        if existing_record:
            continue  # Skip existing records
        
        result['id'] = id
        
        # Préparer les données pour DynamoDB en supprimant 'abstract'
        dynamodb_data = result.copy()  # Créer une copie pour DynamoDB
        if 'abstract' in dynamodb_data:
            del dynamodb_data['abstract']
        
        insert_customer_record(dynamodb_data)
        
        # Sauvegarder l'enregistrement complet, y compris 'abstract', dans S3
        key = f'{query}/result_{idx+1}.json'
        s3.put_object(Bucket=bucket_name, Key=key, Body=json.dumps(result))
    
    return {
        'statusCode': 200,
        'query': query
    }
