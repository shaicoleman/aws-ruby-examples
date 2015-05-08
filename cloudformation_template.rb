# Based on https://github.com/stevenjack/cfndsl/blob/master/sample/autoscale2.rb

# cfndsl cloudformation_template.rb | jq .

CloudFormation {
  require './helpers'

  AWSTemplateFormatVersion "2010-09-09"

  Description <<-DESC.gsub(/^ +/, '')
    Create a multi-az, load balanced, Auto Scaled sample web site. The
    Auto Scaling trigger is based on the CPU utilization of the web
    servers. The AMI is chosen based on the region in which the stack is
    run. This example creates a web service running across all
    availability zones in a region. The instances are load balanced with a
    simple health check. The web site is available on port 80, however,
    the instances can be configured to listen on any port (8888 by
    default).
  DESC

  Parameter("InstanceType") {
    Description "Type of EC2 instance to launch"
    Type "String"
    Default "t2.micro"
    AllowedValues INSTANCE_TYPES
  }

  Parameter( "WebServerPort") {
    Description "The TCP port for the Web Server"
    Type "String"
    Default "8888"
  }
  Parameter("KeyName") {
    Description "The EC2 Key Pair to allow SSH access to the instances"
    Type "String"
  }

  Mapping("AWSRegionArch2AMI", cfn_ubuntu_region_arch_to_ami)

  Mapping("AWSInstanceType2Arch", cfn_instance_type_to_arch)

  # Resources work similar to Parameters
  AutoScalingGroup("WebServerGroup") {
    UpdatePolicy("AutoScalingRollingUpdate", {
                   "MinInstancesInService" => "1",
                   "MaxBatchSize"          => "1",
                   "PauseTime"             => "PT15M"
                   })
    AvailabilityZones FnGetAZs("")
    LaunchConfigurationName Ref("LaunchConfig")
    MinSize 1
    MaxSize 3
    LoadBalancerNames Ref( "ElasticLoadBalancer" )
  }

  LaunchConfiguration("LaunchConfig") {
    KeyName Ref("KeyName")
    ImageId FnFindInMap( "AWSRegionArch2AMI",
                         Ref("AWS::Region"),
                         FnFindInMap( "AWSInstanceType2Arch", Ref("InstanceType"), "Arch") )

    UserData FnBase64( Ref("WebServerPort"))
    SecurityGroup Ref("InstanceSecurityGroup")
    InstanceType Ref("InstanceType")
  }

  Resource( "WebServerScaleUpPolicy" ) {
    Type "AWS::AutoScaling::ScalingPolicy"
    Property("AdjustmentType", "ChangeInCapacity")
    Property("AutoScalingGroupName", Ref( "WebServerGroup") )
    Property("Cooldown", "60")
    Property("ScalingAdjustment", "1")
  }

  Resource("WebServerScaleDownPolicy") {
    Type "AWS::AutoScaling::ScalingPolicy"
    Property("AdjustmentType", "ChangeInCapacity")
    Property("AutoScalingGroupName", Ref( "WebServerGroup" ))
    Property("Cooldown", "60")
    Property("ScalingAdjustment", "-1")
  }

  alarms = []
  alarms.push Resource("CPUAlarmHigh") {
    Type "AWS::CloudWatch::Alarm"
    Property("AlarmDescription", "Scale-up if CPU > 90% for 10 minutes")
    Property("Threshold", "90")
    Property("AlarmActions", [ Ref("WebServerScaleUpPolicy" ) ])
    Property("ComparisonOperator", "GreaterThanThreshold")
  }

  alarms.push Resource("CPUAlarmLow") {
    Type "AWS::CloudWatch::Alarm"
    Property("AlarmDescription", "Scale-down if CPU < 70% for 10 minutes")
    Property("Threshold", "70")
    Property("AlarmActions", [ Ref("WebServerScaleDownPolicy" ) ])
    Property("ComparisonOperator", "LessThanThreshold")
  }

  alarms.each do |alarm|
    alarm.declare {
      Property("MetricName", "CPUUtilization")
      Property("Namespace", "AWS/EC2")
      Property("Statistic", "Average")
      Property("Period", "300")
      Property("EvaluationPeriods", "2")
      Property("Dimensions", [ { "Name" => "AutoScalingGroupName",
                                 "Value" => Ref("WebServerGroup" ) } ] )
    }
  end

  Resource( "ElasticLoadBalancer" ) {
    Type "AWS::ElasticLoadBalancing::LoadBalancer"
    Property( "AvailabilityZones", FnGetAZs(""))
    Property( "Listeners" , [ { "LoadBalancerPort" => "80",
                                "InstancePort" => Ref( "WebServerPort" ),
                                "Protocol" => "HTTP" } ] )
    Property( "HealthCheck" , {
                # FnFormat replaces %0, %1, etc with passed in parameters
                # Note that it renders to a call to Fn::Join in the json.
                "Target" => FnFormat("HTTP:%0/", Ref( "WebServerPort" ) ),
                "HealthyThreshold" => "3",
                "UnhealthyThreshold" => "5",
                "Interval" => "30",
                "Timeout" => "5"
              })
  }

  Resource("InstanceSecurityGroup" ) {
    Type "AWS::EC2::SecurityGroup"
    Property("GroupDescription" , "Enable SSH access and HTTP access on the inbound port")
    Property("SecurityGroupIngress", [ {
          "IpProtocol" => "tcp",
          "FromPort" => "22",
          "ToPort" => "22",
          "CidrIp" => "0.0.0.0/0"
        },
        {
          "IpProtocol" => "tcp",
          "FromPort" => Ref( "WebServerPort" ),
          "ToPort" => Ref( "WebServerPort" ),
          "SourceSecurityGroupOwnerId" => FnGetAtt("ElasticLoadBalancer", "SourceSecurityGroup.OwnerAlias"),
          "SourceSecurityGroupName" => FnGetAtt("ElasticLoadBalancer", "SourceSecurityGroup.GroupName")
        } ])
  }

  Output( "URL" ) {
    Description "The URL of the website"
    Value FnJoin( "", [ "http://", FnGetAtt( "ElasticLoadBalancer", "DNSName" ) ] )
  }

}
