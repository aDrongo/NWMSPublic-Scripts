import urllib3
import json
import os

token_id = os.environ.get('token_id')
token_value = os.environ.get('token_value')
base_url = "https://isonaspureaccesscloud.com/api/v2/"
api_cred = "credentials"

def lambda_handler(event, context):
    result = Create_Credential(str(event['user_id']),str(event['card_id']),str(event['card_data']))
    return {
        'statusCode': 200,
        'body': result
    }

def Get_HexValue(card_id,card_data):
    h = f'{int(card_id):X}'
    return "0"*(8-len(h)) + h + "0"*14 + card_data

def Create_Credential(user_id,card_id,card_data):
    data = json.dumps([{
        'displayValue': card_id,
        'userId': user_id,
        'rawValue': Get_HexValue(card_id,card_data),
        'credentialType': 'Badge',
        'entryLimitEnagled': False,
        'isDisabled': False
    }])
    headers = urllib3.util.make_headers(basic_auth=f"{token_id}:{token_value}")
    headers['Content-Type'] = 'application/json'
    http = urllib3.PoolManager()
    r = http.request('POST',base_url+api_cred,body=data,headers=headers)
    return r.data.decode('utf-8')