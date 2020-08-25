import urllib3
import json
import os

def lambda_handler(event, context):
    result = modify_user(str(event['user_id']),str(event['disabled']))
    return {
        'statusCode': 200,
        'body': result
    }

def get_basic_headers():
    token_id = os.environ.get('token_id')
    token_value = os.environ.get('token_value')
    return urllib3.util.make_headers(basic_auth=f"{token_id}:{token_value}")

def modify_user(user_id,disabled):
    base_url = "https://isonaspureaccesscloud.com/api/v2/"
    api_users = "users"
    data = json.dumps([{
        'id': user_id,
        'isDisabled': disabled
    }])
    headers = get_basic_headers()
    headers['Content-Type'] = 'application/merge-patch+json'
    http = urllib3.PoolManager()
    r = http.request('PATCH',base_url+api_users,body=data,headers=headers)
    return r.data.decode('utf-8')