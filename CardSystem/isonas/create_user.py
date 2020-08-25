import urllib3
import json
import os

token_id = os.environ.get('token_id')
token_value = os.environ.get('token_value')
base_url = "https://isonaspureaccesscloud.com/api/v2/"
api_users = "users"
api_cred = "credentials"

def lambda_handler(event, context):
    result = Create_User(str(event['first_name']),str(event['last_name']),str(event['rey_id']))
    return {
        'statusCode': 200,
        'body': result
    }

def Create_User(first_name, last_name, rey_id):
    data = json.dumps([{
        'firstName': first_name,
        'lastName': last_name,
        'employeeId': rey_id,
        'role': 'CardHolder',
        'isDisabled': 'false'
    }])
    headers = urllib3.util.make_headers(basic_auth=f"{token_id}:{token_value}")
    headers['Content-Type'] = 'application/json'
    http = urllib3.PoolManager()
    r = http.request('POST',base_url+api_users,body=data,headers=headers)
    return r.data.decode('utf-8')