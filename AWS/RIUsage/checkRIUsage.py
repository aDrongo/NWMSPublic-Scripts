#Need to install AWS CLI and run aws configure first
#Need to pip install pandas and openpyxl and xlsxwriter

import boto3
import datetime
import pandas

class Instance:
    id = ""
    name = ""
    ec2type = ""
    platform = ""
    reserved = False

    def __init__(self,id,ec2type):
        self.id = id
        self.ec2type = ec2type
    
    def addName(self,name):
        self.name = name
    
    def addPlatform(self,platform):
        self.platform = platform
    
    def __repr__(self):
        return f"{self.name}"
    
    def toDict(self):
        return dict(Name = self.name,
                    Type = self.ec2type,
                    Platform = self.platform,
                    Reserved = self.reserved)

class Reservation:
    ec2type = ""
    platform = ""
    consumed = False

    def __init__(self, ec2type, platform):
        self.ec2type = ec2type
        self.platform = platform

    def toDict(self):
        return dict(Type = self.ec2type,
                    Platform = self.platform,
                    Consumed = self.consumed)

class ReservationUsage:
    instances = []
    reservations = []

    def __init__(self):
        self.getReservations()
        self.getInstances()
    
    def getReservations(self):
        ec2 = boto3.client('ec2')
        prelim_reservations = ec2.describe_reserved_instances()['ReservedInstances']
        for reservation in prelim_reservations:
            if reservation['State'] == 'active':
                count = int(reservation['InstanceCount'])
                for i in range(count):
                    newReservation = Reservation(reservation['InstanceType'],reservation['ProductDescription'])
                    self.reservations.append(newReservation)
    
    def getInstances(self):
        ec2 = boto3.client('ec2')
        ec2Instances = ec2.describe_instances()['Reservations']
        for instance in ec2Instances:
            instanceDetails = instance['Instances'][0]
            if instanceDetails['State']['Name'] == 'running':
                newInstance = Instance(instanceDetails['InstanceId'],instanceDetails['InstanceType'])
                newInstance.addName(self._getTag(instanceDetails['Tags'], 'Name'))
                newInstance.addPlatform(self._getTag(instanceDetails['Tags'], 'Platform'))
                self.instances.append(newInstance)

    def _getTag(self, tags, key):
            for tag in tags:
                if tag.get('Key') == key:
                    return tag['Value']
            return "None"
    
    def getUsedAndReserved(self):
        for reservation in self.reservations:
            for instance in self.instances:
                if (instance.reserved != True and 
                        instance.ec2type == reservation.ec2type and 
                        instance.platform in reservation.platform):
                    instance.reserved = True
                    reservation.consumed = True
                    break

    def _getDataFrame(self,objects):
        exportList = []
        for obj in objects:
            exportList.append(obj.toDict())
        return pandas.DataFrame(exportList)

    def exportExcel(self):
        df1 = self._getDataFrame(self.reservations)
        df2 = self._getDataFrame(self.instances)
        writer = pandas.ExcelWriter('Reservations.xlsx', engine='xlsxwriter')
        df1.to_excel(writer, sheet_name='RIs')
        df2.to_excel(writer, sheet_name='Instances')
        writer.save()

def s3Upload(filePath, bucket):
    s3 = boto3.resource('s3')
    s3.meta.client.upload_file(filePath, bucket, filePath)

if __name__ == "__main__":
    reserveUsage = ReservationUsage()
    reserveUsage.getUsedAndReserved()
    reserveUsage.exportExcel()
    s3Upload('Reservations.xlsx',"reports.contoso.com")
