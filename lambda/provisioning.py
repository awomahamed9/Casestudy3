import json
import os
import boto3
import pymysql

# AWS clients
cognito = boto3.client('cognito-idp')

# Environment variables
DB_HOST = os.environ['DB_HOST'].split(':')[0]
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
USER_POOL_ID = os.environ.get('USER_POOL_ID', '')

def lambda_handler(event, context):
    employee = event.get('employee', {})
    employee_id = employee.get('id')
    employee_name = employee.get('name')
    employee_email = employee.get('email')
    employee_dept = employee.get('department', 'General')
    
    print(f"Provisioning for: {employee_name} ({employee_email})")
    
    try:
        # 1. Create Cognito user account
        if USER_POOL_ID:
            try:
                cognito.admin_create_user(
                    UserPoolId=USER_POOL_ID,
                    Username=employee_email,
                    UserAttributes=[
                        {'Name': 'email', 'Value': employee_email},
                        {'Name': 'email_verified', 'Value': 'true'},
                        {'Name': 'given_name', 'Value': employee_name},
                        {'Name': 'custom:department', 'Value': employee_dept}
                    ],
                    TemporaryPassword='TempPass123!',
                    DesiredDeliveryMediums=['EMAIL']
                )
                print(f"✅ Cognito account created for {employee_email}")
                
                # Add to employees group
                cognito.admin_add_user_to_group(
                    UserPoolId=USER_POOL_ID,
                    Username=employee_email,
                    GroupName='employees'
                )
                print(f"✅ Added to 'employees' group")
                
            except cognito.exceptions.UsernameExistsException:
                print(f"⚠️  User {employee_email} already exists in Cognito")
            except Exception as e:
                print(f"⚠️  Cognito error: {str(e)}")
        
        # 2. Update database status
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=5
        )
        
        with connection.cursor() as cursor:
            sql = "UPDATE employees SET status = 'active' WHERE id = %s"
            cursor.execute(sql, (employee_id,))
            connection.commit()
            print(f"✅ Database updated: {employee_name} -> active")
        
        connection.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'User {employee_name} provisioned successfully',
                'employee_id': employee_id,
                'cognito_created': bool(USER_POOL_ID)
            })
        }
        
    except Exception as e:
        print(f"❌ Provisioning error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }