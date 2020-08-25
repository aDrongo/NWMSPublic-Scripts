import urllib3
import json
import os

token_id = os.environ.get('token_id')
token_value = os.environ.get('token_value')
base_url = "https://isonaspureaccesscloud.com/api/v2/"
api_cred = "credentials"

def lambda_handler(event, context):
    result = Disable_Credential(str(event['user_id']),str(event['disabled']))
    return {
        'statusCode': 200,
        'body': result
    }

def Get_Credentials(user_id):
    url = base_url + api_cred + f"?includeDisabled=true&userIds={user_id}"
    headers = urllib3.util.make_headers(basic_auth=f"{token_id}:{token_value}")
    http = urllib3.PoolManager()
    r = http.request('GET',url,headers=headers)
    return r.data.decode('utf-8')

def Disable_Credential(user_id, disabled):
    if (disabled != "true") and (disabled != "false"):
        raise Exception("disabled must be true or false")
    credentials = json.loads(Get_Credentials(user_id))
    found = False
    for c in credentials:
        if str(c['userId']) == str(user_id):
            data = json.dumps([{
                'id': c['id'],
                'isDisabled': f"{disabled}",
                "entryLimitEnabled": "true",
                "entryLimit": "9999"
            }])
            headers = urllib3.util.make_headers(basic_auth=f"{token_id}:{token_value}")
            headers['Content-Type'] = 'application/merge-patch+json'
            http = urllib3.PoolManager()
            r = http.request('PATCH',base_url+api_cred,body=data,headers=headers)
            return r.data.decode('utf-8')
            found = True
    if found == True:
        return r.data.decode('utf-8')
    else:
        return None