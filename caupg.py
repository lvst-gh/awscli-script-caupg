import boto3

if __name__ == '__main__':
    EC2 = boto3.client('ec2')
    regions = EC2.describe_regions()


    for REGION in regions['Regions']:
        RDS = boto3.client('rds',REGION['RegionName'])
        cls = RDS.describe_db_instances()
        if len(cls['DBInstances']) > 0:
            print("Region: ",REGION['RegionName'],"\t",len(cls['DBInstances'])," found.")
            for inst in cls['DBInstances']:
                if inst['CACertificateIdentifier'] == 'rds-ca-2015':
                    try:
                        caupg = RDS.modify_db_instance(
                            DBInstanceIdentifier=inst['DBInstanceIdentifier'],
                            ApplyImmediately=True,
                            CACertificateIdentifier='rds-ca-2019',
                            CertificateRotationRestart=False
                        )
                        print("\tCA has been updated for ",inst['DBInstanceIdentifier'])
                    except Exception as e:
                        print("\tFailed to upgrade ",inst['DBInstanceIdentifier'],"\t Exception: ",e)
                        pass
                    continue
                else:
                    print("\t",inst['DBInstanceIdentifier']," doesn't match.")
        else:
            print("Region: ",REGION['RegionName'],"\tNo instances need upgrade.")
