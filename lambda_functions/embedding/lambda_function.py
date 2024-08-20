import json
import uuid
import os
import logging

import boto3
from pinecone import Pinecone, ServerlessSpec
from botocore.exceptions import ClientError

s3=boto3.client('s3')
client = boto3.client("sagemaker-runtime", region_name="us-east-1")
# Environment variables
INDEX_NAME = os.getenv("INDEX_NAME")
API_KEY_PINECONE = os.getenv("API_key_pinecone")
ENDPOINT_NAME = os.getenv("ENDPOINT_NAME")

pinecone = Pinecone(api_key=API_KEY_PINECONE)
# Constants
DIMS = 384  # Dimensions for embeddings

def custom_text_splitter(text, chunk_size=1200, chunk_overlap=200, separator="."):
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        if end >= len(text):
            chunks.append(text[start:])
            break
        split_pos = text.rfind(separator, start, end)
        if split_pos == -1 or split_pos < start:
            split_pos = end
        chunks.append(text[start:split_pos].strip())
        start = split_pos + len(separator) - chunk_overlap
    return chunks


def embed(index, embeddings, texts, id):
    prepped = []
    for i, embedding in enumerate(embeddings):
        prepped.append({
            'id': str(uuid.uuid4()),
            'values': embedding,
            'metadata': {'id': id, 'body': texts[i]}
        })
    try:
        index.upsert(prepped, namespace="ns1")
        logger.info("Successfully upserted %d embeddings.", len(prepped))
    except Exception as e:
        logger.error("Error upserting embeddings: %s", str(e))
        raise

def lambda_handler(event, context):
    # TODO implement
    bucket_name="sfcr-projet"
    key_file=event['key_file']
    response = s3.get_object(Bucket=bucket_name, Key=key_file)
    file_content = response['Body'].read().decode('utf-8')
    data = json.loads(file_content)

    abstract=data['abstract']
    id=data['id']
    texts=custom_text_splitter(abstract)
    
    
    body = {
            "inputs": texts
        }

    response = client.invoke_endpoint(
        EndpointName=ENDPOINT_NAME,
        ContentType="application/json",
        Accept="application/json",
        Body=json.dumps(body),
    )
    
    response_body = response['Body'].read().decode('utf-8')
    results = json.loads(response_body)
    index = pinecone.Index(INDEX_NAME)
    embed(index, results, texts, id)

    
    return {
        'statusCode': 200,
        'body': data['url_abs']
    }
