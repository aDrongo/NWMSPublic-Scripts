import json
import os
import requests
from json2html import *


def lambda_handler(event, context):
    # print(event)
    # TODO implement
    webhook_url = os.environ['url']
    html_data = json2html.convert(json=event)
    webhook_data = {
        "title": "AWS Alert",
        "text": f"{html_data}"
    }
    response = requests.post(webhook_url, json=webhook_data, headers={'Content-Type': 'application/json'})
    response_dict = {f"{response.status_code}": f"{response.content}"}
    return response_dict
