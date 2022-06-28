require 'ap'
require './helpers'
require 'byebug'

# ec2
@region = get_region_from_config
@key_name = 'aws-example-keyname'

# autoscaling
@launch_configuration_name = 'autoscaling_test'
@auto_scaling_group_name = 'autoscaling-test-group'

# cloudformation
@stack_name = 'WordPress-sample-basic'

# dynamodb
@table_name = 'GameScores'

# ebs
@availability_zone = 'us-east-1e'
@volume_id         = 'vol-4f203a00'
@instance_id       = 'i-83b4e0ac'

# elasticache
@cache_cluster_id = 'mycachecluster'

# elb
@load_balancer_name = 'elb-test'

# sns
@topic_name = 'example_test'
@display_name = 'Example Topic'
@email = 'example@example.com'
@phone = '+1 234 567 8901'  # US mobiles only
@http_endpoint = 'http://example.com/'
@queue_arn = 'arn:aws:sqs:us-east-1:123456789012:example_test'

# sqs
@queue_name = 'example_test'
