import paramiko
import socket
import json
import re
import os
import time

def lambda_handler(event, context):
    result = Create_Card(event['card_id'])
    return {
        'statusCode': 200,
        'body': result
    }

def Create_Card(card_id):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    user = os.environ.get("user")
    passw = os.environ.get("pass")
    proxmark_ip = os.environ.get("proxmark_ip")
    client.connect(proxmark_ip, username=user, password=passw)
    stdin, stdout, stderr = client.exec_command('/home/proxmark3/proxmark3/client/proxmark3 /dev/ttyACM0')
    
    stdin.write(f'script run lf_bulk_program.lua -f 13 -b {card_id} -c 1\n')
    stdin.flush()
    stdin.write('\n')
    stdin.flush()
    stdin.write('lf search u\nquit\n')
    stdin.flush()
    output = stdout.read().decode("utf-8")
    client.close()
    search = re.findall(r"ID:\s*\S{10}", output)
    if len(search) > 0:
        search = search[0][4:]
    else:
        search = None
    return search