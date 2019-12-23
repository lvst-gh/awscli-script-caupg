export REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

for REGION in $REGIONS; do
    INSTS=$(aws rds describe-db-instances --query "DBInstances[?CACertificateIdentifier=='rds-ca-2015'].DBInstanceIdentifier" --output text --region $REGION)
    if [ "$INSTS" != "" ];
    then
        echo -e "REGION:\t $REGION\tRDS: $INSTS\t"
        for INSTANCE in $INSTS; do
            echo -e "`date`\tUpgrade CA for instance\t$INSTANCE"
            aws rds modify-db-instance --db-instance-identifier $INSTANCE \
                --ca-certificate-identifier rds-ca-2019 \
                --no-certificate-rotation-restart \
                --apply-immediately \
                --query 'DBInstance.PendingModifiedValues' \
                --output table \
                --region $REGION
            if [ "$?" != "0" ];
            then echo -e "\t`date`\t Failed to upgrade ca for instance: \t$INSTANCE"
            fi
            sleep 1;
        done
    else
        echo -e "REGION:\t $REGION\tRDS: No instances need upgrade\t"
    fi
done
