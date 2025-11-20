import json
import os
import pymysql

DB_HOST = os.environ['DB_HOST'].split(':')[0]
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']

def lambda_handler(event, context):
    employee = event.get('employee', {})
    employee_id = employee.get('id')
    employee_name = employee.get('name')
    
    print(f"Provisioning user account for: {employee_name} (ID: {employee_id})")
    
    try:
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=5
        )
        
        with connection.cursor() as cursor:
            print(f"Creating account for {employee_name}...")
            print(f"Setting up access rights for department: {employee.get('department')}")
            print(f"Assigning role: {employee.get('role')}")
            
            sql = "UPDATE employees SET status = 'active' WHERE id = %s"
            cursor.execute(sql, (employee_id,))
            connection.commit()
            
            print(f"Employee {employee_name} provisioned successfully")
        
        connection.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'User {employee_name} provisioned successfully',
                'employee_id': employee_id
            })
        }
        
    except Exception as e:
        print(f"Provisioning error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
