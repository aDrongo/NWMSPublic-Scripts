import isonas.create_credential
import isonas.get_users
import proxmark.proxmark
import os

Print("This script will (optionally) create a ISONAS user then create and attach a card to a User")

token_id = os.environ.get("token_id")
token_value = os.environ.get("token_value")

if "Y" in input("Create a user? Y/N: "):
    first = input("First Name: ")
    last = input("Last Name: ")
    rey_id = input("Reynolds/Employee ID: ")
    print(isonas.create_user.Create_User(first, last, rey_id))

users = isonas.get_users.get_sorted_users()
max_card_id = 0
user_ids_list = []

print("  user_id | rey_id | firstname lastname")
print("---------------------------------------")
for row in users:
    if row.disabled == False:
        print(f"{row.user_id:>9} | {row.rey_id:>6} | {row.first_name:>10} {row.last_name:<10}")
        user_ids_list.append(int(row.user_id))
        try:
            if int(row.card_id) > max_card_id:
                max_card_id = int(row.card_id)
        except ValueError:  #don't want to crash application if it fails to typecast, crash for any other error though.
            pass

user_id = 0
while user_id not in user_ids_list:
    user_id = int(input("Please select a user_id: "))

user_id = str(user_id)
card_id = max_card_id + 1

input("Creating Card, please ensure card is on proxmark. Press enter to continue")
card_data = proxmark.proxmark.Create_Card(card_id)
result = isonas.create_credential.Create_Credential(user_id,card_id,card_data)
print(result)
print()