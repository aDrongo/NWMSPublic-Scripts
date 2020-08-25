import isonas.modify_user
import isonas.get_users
import os

os.environ['token_id'] = os.environ.get("token_id")
os.environ['token_value'] = os.environ.get("token_value")

users = isonas.get_users.get_users()
user_ids_list = []

print("  user_id | rey_id | firstname lastname")
print("---------------------------------------")
for row in users:
    if row['isDisabled'] == False:
        print(f"{row['id']:>9} | {row['employeeId']:>6} | {row['firstName']:>10} {row['lastName']:<10}")
        user_ids_list.append(int(row['id']))

user_id = 0
while user_id not in user_ids_list:
    user_id = int(input("Please select a user_id: "))

user_id = str(user_id)

print(isonas.modify_user.modify_user(user_id,True))