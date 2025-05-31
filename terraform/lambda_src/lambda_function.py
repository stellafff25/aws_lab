import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    for record in event['Records']:
        src_bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        dest_bucket = 's3-finish'
        
        copy_source = {'Bucket': src_bucket, 'Key': key}
        
        s3.copy_object(
            Bucket=dest_bucket,
            CopySource=copy_source,
            Key=key
        )
        
    return {'statusCode': 200, 'body': 'File copied successfully'}

