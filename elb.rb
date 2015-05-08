require './config'

def elb
  @elb ||= Aws::ElasticLoadBalancing::Client.new(region: @region)
end

def create_load_balancer
  listeners = [{ protocol:          'http', load_balancer_port: 80,
                 instance_protocol: 'http', instance_port:      80 }];
  subnets = %w[subnet-4b7c1b3c subnet-29fc7870 subnet-4975d862 subnet-68551e52]
  security_groups = ['sg-a20192c6']

  resp = elb.create_load_balancer \
    @load_balancer_name: @load_balancer_name, listeners: listeners,
    subnets: subnets, security_groups: security_groups
  ap resp
end

def configure_health_check
  health_check = {
    target: 'HTTP:80/', timeout: 2, interval: 6,
    unhealthy_threshold: 2, healthy_threshold: 2 }
  resp = elb.configure_health_check \
    load_balancer_name: @load_balancer_name, health_check: health_check
  ap resp
end

def configure_attributes
  load_balancer_attributes = {
    cross_zone_load_balancing: { enabled: true },
    connection_draining: { enabled: true, timeout: 300 },
    connection_settings: { idle_timeout: 60 } }
  resp = elb.modify_load_balancer_attributes \
    load_balancer_name: @load_balancer_name,
    load_balancer_attributes: load_balancer_attributes
  ap resp
end

def configure_instances
  instances = [{ instance_id: 'i-15fafeef'}, { instance_id: 'i-baf5f140'}]
  resp = elb.register_instances_with_load_balancer \
    load_balancer_name: @load_balancer_name, instances: instances
  ap resp
end
