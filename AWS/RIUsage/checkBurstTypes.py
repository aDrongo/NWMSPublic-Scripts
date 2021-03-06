#Need to install AWS CLI and run aws configure first
#Need to pip install pandas and openpyxl

import boto3
import datetime
import pandas

class Instance:
    InstanceId = ""
    InstanceName = ""
    InstanceType = ""
    BestType = ""
    BetterTypeAvailable = False
    BestCPU = 0.0
    BaselineCPU = 0.0
    AverageCPU = 0.0

    def __init__(self,InstanceId,InstanceType,InstanceName):
        self.InstanceId = InstanceId
        self.InstanceType = InstanceType
        self.InstanceName = InstanceName

    def getAverageCPU(self):
        metrics = self._getCpuMetrics()
        datapoints = self._getDatapointsfromMetrics(metrics)
        self.AverageCPU = self._getAverage(datapoints)

    def _getCpuMetrics(self):
        cloudwatch = boto3.client('cloudwatch')
        return cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[
                {
                    'Name': 'InstanceId',
                    'Value': self.InstanceId
                },
            ],
            StartTime=datetime.datetime.utcnow() - datetime.timedelta(days=7),
            EndTime=datetime.datetime.utcnow(),
            Period=86400,
            Statistics=[
                'Average'
            ],
            Unit='Percent'
        )

    def _getDatapointsfromMetrics(self, metrics):
        datapoints = []
        for datapoint in metrics['Datapoints']:
            datapoints.append(datapoint['Average'])
        return datapoints

    def _getAverage(self, data):
        if len(data) == 0:
            return 0
        else:
            return sum(data)/len(data)

    def getBestType(self, ec2Types):
        if self.InstanceType not in ec2Types.keys():
            self.BestType = "None"
        else:
            self.BaselineCPU = ec2Types.get(self.InstanceType)['Baseline']
            currentWeight = ec2Types.get(self.InstanceType)['CPUs'] * self.AverageCPU /100
            bestMatch = 't2.nano' #default to start
            for key, value in ec2Types.items():
                if (value['Weight'] > ec2Types[bestMatch]['Weight'] and value['Weight'] < currentWeight):
                    bestMatch = key
            self.BestCPU = ec2Types[bestMatch]['Baseline']
            self.BestType = bestMatch
            if self.BestType != self.InstanceType:
                self.BetterTypeAvailable = True

class EC2Instances:
    instances = []
    ec2BurstTypes = {
        't2.nano': {'CPUs': 1, 'Baseline': 5},
        't2.mirco': {'CPUs': 1, 'Baseline': 10},
        't2.small': {'CPUs': 1, 'Baseline': 20},
        't2.medium': {'CPUs': 2, 'Baseline': 20},
        't2.large': {'CPUs': 2, 'Baseline': 30},
        't2.xlarge': {'CPUs': 4, 'Baseline': 22.5},
        't2.2xlarge': {'CPUs': 8, 'Baseline': 17},
        't3.nano': {'CPUs': 2, 'Baseline': 5},
        't3.mirco': {'CPUs': 2, 'Baseline': 10},
        't3.small': {'CPUs': 2, 'Baseline': 20},
        't3.medium': {'CPUs': 2, 'Baseline': 20},
        't3.large': {'CPUs': 2, 'Baseline': 30},
        't3.xlarge': {'CPUs': 4, 'Baseline': 22.5},
        't3.2xlarge': {'CPUs': 8, 'Baseline': 17},
        't3a.nano': {'CPUs': 2, 'Baseline': 5},
        't3a.mirco': {'CPUs': 2, 'Baseline': 10},
        't3a.small': {'CPUs': 2, 'Baseline': 20},
        't3a.medium': {'CPUs': 2, 'Baseline': 20},
        't3a.large': {'CPUs': 2, 'Baseline': 30},
        't3a.xlarge': {'CPUs': 4, 'Baseline': 22.5},
        't3a.2xlarge': {'CPUs': 8, 'Baseline': 17}
    }

    def __init__(self):
        self.getInstances()
        self.getEC2Weights()

    def getEC2Weights(self):
        for key, value in self.ec2BurstTypes.items():
            self.ec2BurstTypes[key]['Weight'] = value['CPUs'] * value['Baseline'] /100

    def getInstances(self):
        ec2 = boto3.client('ec2')
        ec2Instances = ec2.describe_instances()
        for instance in ec2Instances['Reservations']:
            instanceDetails = instance['Instances'][0]
            if instanceDetails['State']['Name'] == 'running':
                nameTag = self._getNametag(instanceDetails['Tags'])
                newInstance = Instance(instanceDetails['InstanceId'],instanceDetails['InstanceType'],nameTag)
                self.instances.append(newInstance)
    
    def _getNametag(self, tags):
            for tag in tags:
                if tag.get('Key') == 'Name':
                    return tag['Value']
    
    def getAverageCPUs(self):
        for instance in self.instances:
            instance.getAverageCPU()
    
    def getBestTypes(self):
        for instance in self.instances:
            instance.getBestType(self.ec2BurstTypes)

    def exportExcel(self):
        exportList = []
        for instance in self.instances:
            exportList.append(instance.__dict__)
        df = pandas.DataFrame(exportList)
        df.to_excel(r'checkBurstTypes.xlsx')
    
if __name__ == "__main__":
    ec2Instances = EC2Instances()
    ec2Instances.getAverageCPUs()
    ec2Instances.getBestTypes()
    ec2Instances.exportExcel()
