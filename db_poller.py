import json
import os
import boto3
import pymysql
from datetime import datetime

lambda_client = boto3.client('lambda')

DB_HOST = os.environ['DB_HOST'].split(':')[0]
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
PROVISIONING_LAMBDA = os.environ['PROVISIONING_LAMBDA']
EMAIL_LAMBDA = os.environ['EMAIL_LAMBDA']

def datetime_converter(o):
    if isinstance(o, datetime):
        return o.isoformat()

def lambda_handler(event, context):
    print("Starting DB poll for pending employees...")
    
    try:
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=5
        )
        
        with connection.cursor(pymysql.cursors.DictCursor) as cursor:
            sql = "SELECT * FROM employees WHERE status = 'pending'"
            cursor.execute(sql)
            pending_employees = cursor.fetchall()
            
            print(f"Found {len(pending_employees)} pending employees")
            
            for employee in pending_employees:
                print(f"Processing employee: {employee['name']} ({employee['email']})")
                
                try:
                    prov_response = lambda_client.invoke(
                        FunctionName=PROVISIONING_LAMBDA,
                        InvocationType='RequestResponse',
                        Payload=json.dumps({'employee': employee}, default=datetime_converter)
                    )
                    print(f"Provisioning response: {prov_response['StatusCode']}")
                except Exception as e:
                    print(f"Error invoking provisioning: {str(e)}")
                
                try:
                    email_response = lambda_client.invoke(
                        FunctionName=EMAIL_LAMBDA,
                        InvocationType='RequestResponse',
                        Payload=json.dumps({'employee': employee}, default=datetime_converter)
                    )
                    print(f"Email response: {email_response['StatusCode']}")
                except Exception as e:
                    print(f"Error invoking email: {str(e)}")
        
        connection.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Processed {len(pending_employees)} employees')
        }
        
    except Exception as e:
        print(f"Database error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
