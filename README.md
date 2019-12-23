Hi,All
      Good news, CA certificate upgrade has been simplifized as one API call, and unbind with RDS instance, that it means that no down time during the upgrade. And during my test, no TX or connection failure was observed.
      But there is still things to do, I add a new version and it will help you:
      1.go through all regions to find RDS instances with 2015 ca;
      2.record upgrade time for further diagnosing(IF SOMETHING WRONG);
      
      I hope it may help your customer to experience real customer obsession.
      Test before try, always.
