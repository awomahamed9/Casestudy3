import json
import os
import boto3

sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    employee = event.get('employee', {})
    name = employee.get('name')
    email = employee.get('email')
    department = employee.get('department')
    role = employee.get('role')
    
    print(f"Sending welcome email to: {name} ({email})")
    
    subject = f"Welcome to Innovatech, {name}!"
    
    message = f"""
Hello {name},

Welcome to Innovatech Solutions!

Your account has been successfully created with the following details:

Name: {name}
Email: {email}
Department: {department}
Role: {role}

Your IT access has been provisioned and you should now be able to access:
- Email system
- Company intranet
- Department-specific applications

If you have any questions, please contact IT support.

Best regards,
Innovatech IT Team
"""
    
    try:
        response = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        
        print(f"Email sent successfully. MessageId: {response['MessageId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Welcome email sent to {email}',
                'messageId': response['MessageId']
            })
        }
        
    except Exception as e:
        print(f"Error sending email: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
