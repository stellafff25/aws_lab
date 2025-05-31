import boto3

s3 = boto3.client('s3', endpoint_url='http://localhost:4566')

def lambda_handler(event, context):
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    destination_bucket = 's3-finish'

    s3.copy_object(
        CopySource={'Bucket': source_bucket, 'Key': key},
        Bucket=destination_bucket,
        Key=key
    )

    return {
        'statusCode': 200,
        'body': f'File {key} copied from {source_bucket} to {destination_bucket}'
    }
