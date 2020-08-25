import urllib3
import json
import os

base_url = "https://isonaspureaccesscloud.com/api/v2/"
api_cred = "credentials"
api_users = "users?includeDisabled=true"

class User:
    card_id = 0
    card_data = ""
    cred_id = ""

    def __init__(self, user_id,first_name,last_name,rey_id,disabled):
        self.user_id = user_id
        self.first_name = first_name
        self.last_name = last_name
        self.rey_id = rey_id
        self.disabled = disabled
    
    def set_card(self, card_id,card_data,cred_id):
        self.card_id = card_id
        self.card_data = card_data
        self.cred_id = cred_id
    
    def get_user_id(self):
        return self.user_id
    
    def get_card_id(self):
        return self.card_id
    
    def set_card_id(self, card_id):
        self.card_id = card_id
    
    def __repr__(self):
        return f"{self.__dict__}"

    def to_json(self):
        return self.__dict__

#JSON conversion for our class object
def _default(self, obj):
    return getattr(obj.__class__, "to_json", _default.default)(obj)

_default.default = json.JSONEncoder().default
json.JSONEncoder.default = _default


def get_basic_headers():
    token_id = os.environ.get('token_id')
    token_value = os.environ.get('token_value')
    return urllib3.util.make_headers(basic_auth=f"{token_id}:{token_value}")

def get_users():
    headers = get_basic_headers()
    http = urllib3.PoolManager()
    r = http.request('GET',base_url+api_users,headers=headers)
    return json.loads(r.data.decode('utf-8'))

def get_credentials():
    headers = get_basic_headers()
    http = urllib3.PoolManager()
    r = http.request('GET',base_url+api_cred,headers=headers)
    return json.loads(r.data.decode('utf-8'))
    
def match_credentials_with_user(user,creds):
    for c in creds:
        try:
            if str(c['userId']) == str(user.get_user_id()):
                if int(c['displayValue']) > int(user.get_card_id()): #Only attach largest card id to user. Need the largest ID for incrementing when creating a new card.
                    user.set_card(
                        card_id = c['displayValue'],
                        card_data = c['rawValue'],
                        cred_id = c['id']
                    )
        except ValueError:
            pass

def get_sorted_users():
    users = get_users()
    credentials = get_credentials()
    sorted_users = []
    for u in users:
        sorted_users.append(User(
            u['id'],
            u['firstName'],
            u['lastName'],
            u['employeeId'],
            u['isDisabled']))
        match_credentials_with_user(sorted_users[-1],credentials)
    return sorted_users

def lambda_handler(event, context):
    users = get_sorted_users()
    return {
        'statusCode': 200,
        'body': json.dumps(users)
    }
