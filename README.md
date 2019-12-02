Hi, All
                No guess, our mailboxes must have been flooded by CA Certificate upgrade warning letters, actually not only TAM but also our customers are wondering about the special ‘LSE’ event.  I have a customer who have to finish CA certificate upgrade for more than 5 hundreds of RDS Instance before Feb 4.  It’s so terrible, we must do something here to help them out of the trouble. I have finished some works on this issue, and may be someone is doing the same thing,  to avoid duplicate work, I share to whole team,  
1.	How long the upgrade will take, and how many downtime it will cause to business as estimation?
Answer: 2 minutes and 7 seconds downtime when we upgrade CA certificate for two node Aurora cluster(1 writer+1 reader); 
2.	Is there any way to upgrade CA efficiently, instead of working on console  interface?
Answer: a sample script is here, it has been tested but I could guarantee for nothing(no promise to your CX if you want to share with them), in my opinion it’s only a start point 

Yes, I have done some tests, and also provide to my customers. It’s just my two cents, hope it’s useful to you.

If there are any questions, please feel free to contact me

===如何测试完成时间和业务影响时间
==Aurora测试环境
版本： 5.7 - 2.03.2 
节点： 读+写/2读+写
机型： r5large
区域： 东京
Binlog: 关闭

==测试结果
整个过程2分钟，读写影响时间为7s，测试两次；

==测试脚本, 大家可以协助客户做其它场景的测试。
--script sends request to mysql
mysql -h database-2.cluster-cnk2da9mwyvf.ap-northeast-1.rds.amazonaws.com -P 3306 -u admin  <<EOF
insert into test.test values(1);
commit;
select count(*) cnt, now() tim from test.test;
EOF

--script to start test and monitoring
LOG=abc.out

for i in `seq 100000`; do
    ./mysqlacc.sh >> $LOG 2>>$LOG &
    sleep 1
    pkill mysql
    if [  $? -ne 1 ];then 
        echo `date`" timeout" >> $LOG
    fi
done

===升级方式以及简化工作的脚本
==CA更新方式,修改实例ca证书设置+立即重启完成升级
1.通过modify-db-instance更新读实例的CA证书，使用立即重启完成CA更新；
2.通过modify-db-instance更新写实例的CA证书，使用立即重启完成CA更新；
3.完毕；

                ==简化升级工作的脚本
            --脚本说明
            1.对于Aurora集群，可以用以下命令完成升级
                awscaupg.sh database-1
                这里database-1是集群名
                
                2.对于非Aurora集群，包括RDS Mysql， RDS PG，可以用以下命令完成
                awscaupg.sh instance-1 inst
                这里instance-1是实例名

            3.对于读写分离做的很好的应用，reader上会有较多的负载，我们要考虑避免负载压到一个节点上，系统撑不住的情况。在使用的时候可以： 添加额外的读节点，并通过脚本中cooldown（缺省60秒）控制实例重启的间隔，避免业务在少数节点的堆积。

                #####awscaupg.sh start####
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
#####awscaupg.sh end #### 


