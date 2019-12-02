NEWCA=rds-ca-2019
COOLDOWN=60

showbanner(){
echo
echo "****************************"
echo "* AWSCAUPG v0.5"
echo "****************************"
echo
}

nodecaupg(){
CA=$(aws rds describe-db-instances --db-instance-identifier $1  --query 'DBInstances[].[CACertificateIdentifier]' --output text)
ISTATUS=$(aws rds describe-db-instances --db-instance-identifier $1 --query 'DBInstances[].DBInstanceStatus' --output text)
if [ "$CA" == "$NEWCA" ]; 
then 
    echo "`date` CA of $1 matches with $NEWCA, skip it.";  
    echo "`date`" 
elif [ "$ISTATUS" = "stopped"]; then
    echo "`date` Instance $1 is stopped, please start it and retry, exit.";  
    echo "`date`" 
else
    echo "`date`"
    echo "`date` Before upgrading $1"
    aws rds describe-db-instances --db-instance-identifier $1 --query 'DBInstances[].[DBInstanceIdentifier,CACertificateIdentifier]' --output table
    echo "`date` Upgrading CA"
    aws rds modify-db-instance --db-instance-identifier $1 --ca-certificate-identifier $NEWCA --apply-immediately --query 'DBInstance.PendingModifiedValues' --output table
    echo "`date` Restarting..."
    sleep $COOLDOWN
    echo "`date` After upgrading $1"
    aws rds describe-db-instances --db-instance-identifier $1 --query 'DBInstances[].[DBInstanceIdentifier,CACertificateIdentifier]' --output table
    echo "`date`"
fi
}


if [ "$1" = "" ]; 
then 
    echo 
    echo "Usage: awscaupg.sh database-1             ---for Auora Cluster"
    echo "Usage: awscaupg.sh database-1 inst        ---for Non-Aurora RDS instance"
    echo 
    exit; 
elif [ "$2" = "inst" ]; 
then
    showbanner
    echo "`date` CA Upgrade to $NEWCA for instance $1"
    nodecaupg $1;
elif [ "$2" = "" ]; 
then
    showbanner
    echo "`date` CA Upgrade to $NEWCA for cluster $1"
    CLUSTER=$1
    WRITER=$(aws rds describe-db-clusters --db-cluster-identifier $CLUSTER --query 'DBClusters[].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)
    READERS=$(aws rds describe-db-clusters --db-cluster-identifier $CLUSTER --query 'DBClusters[].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' --output text)
    CSTATUS=$(aws rds describe-db-clusters --db-cluster-identifier $CLUSTER --query 'DBClusters[].Status' --output text)
    if [ "$WRITER" = "" ]; then 
        echo "`date` Error to get reader, please check, exit."; echo "`date`"; exit; 
    elif [ "$CSTATUS" = "stopped" ]; then
        echo "`date` Cluster is stopped, please start and retry, exit."; echo "`date`"; exit; 
    fi
    echo "`date`"
    echo "`date` Writer:$WRITER"
    echo "`date` Reader:$READERS"
    echo "`date`"
    for n in $WRITER $READERS; do
        nodecaupg $n
    done
    echo "`date`"
fi