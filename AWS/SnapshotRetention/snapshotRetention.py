import os
import json
import datetime
import boto3
import logging

class SnapshotRetention:
    def __init__(self):
        self.snapshots = []
        self.ec2 = boto3.client('ec2')
    
    def getSnapshots(self,ownerIds,tags):
        print(dict(
            OwnerIds=ownerIds,
            Tags=tags
        )) #logging
        self.TAGS = tags
        self.snapshots = self.ec2.describe_snapshots(
            OwnerIds = ownerIds, 
            Filters = [{'Name':"tag:Name",'Values':tags}]
        )['Snapshots']
    
    def cleanSnapshots(self, retention):
        print(f'Retention: {retention}')
        for tag in self.TAGS:
            tagSnaps = self.getTagSnaps(tag)
            if (len(tagSnaps) > retention):
                for snap in tagSnaps[retention:]:
                    self.deleteSnapshot(snap)
        
    def getTagSnaps(self, tagValue):
        snaps = []
        for snap in self.snapshots:
            if (snap['Progress'] == '100%' and snap['State'] == 'completed'):
                for tag in snap['Tags']:
                    if (tag['Key'] == 'Name' and tag['Value'] == tagValue):
                        snaps.append(snap)
                        continue
        return self.sortSnaps(snaps)
        
    def sortSnaps(self, snaps):
        return sorted(
            snaps, 
            key=lambda k: k['StartTime'], 
            reverse=True
        )
        
    def deleteSnapshot(self, snapshot):
        print(f"deleting snap: {snapshot['SnapshotId']}") #logging
        result = self.ec2.delete_snapshot(
            SnapshotId=snapshot['SnapshotId']
        )
        print(result)

def lambda_handler(event, context):
    snapshotRetention = SnapshotRetention()
    snapshotRetention.getSnapshots(
        os.getenv('OwnerId').split(','),
        os.getenv('Tags').split(',')
    )
    snapshotRetention.cleanSnapshots(
        int(os.getenv('Retention'))
    )
    
    return {
        'statusCode': 200,
        'body': 'Completed'
    }
