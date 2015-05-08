require './config'

def ec2
  @ec2 ||= Aws::EC2::Client.new(region: @region)
end

def autoscaling
  @autoscaling = Aws::AutoScaling::Client.new(region: @region)
end

def get_vpc_public_subnets_ids
  resp = ec2.describe_subnets
  public_subnets = resp[:subnets].find_all { |s| s[:default_for_az] && s[:map_public_ip_on_launch] }
  public_subnet_ids = public_subnets.map { |s| s[:subnet_id] }
end

def create_security_group
  group_name = 'autoscaling-sg'
  description = 'Ports 22/80/443/ICMP'
  ip_permissions = [
    { ip_protocol: 'tcp',  from_port:  22, to_port:  22, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'tcp',  from_port:  80, to_port:  80, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'tcp',  from_port: 443, to_port: 443, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'icmp', from_port:  -1, to_port:  -1, ip_ranges: [cidr_ip: '0.0.0.0/0'] } ]
  resp = ec2.create_security_group \
    group_name: group_name, description: description
  @group_id = resp[:group_id]
  resp = ec2.authorize_security_group_ingress \
    group_name: group_name, ip_permissions: ip_permissions
  resp
end

def create_launch_configuration
  raise '@launch_configuration_name missing' unless @launch_configuration_name
  raise '@group_id' unless @group_id
  image_id = get_ubuntu_image_id
  security_groups = [@group_id]
  instance_type = 't2.micro'
  user_data = <<-SH.gsub(/^ +/, '')
    #!/bin/bash
    apt-get update >> /var/log/cloud-init-output.log &&
    apt-get -yy install php5 apache2 >> /var/log/cloud-init-output.log &&
    echo -e "<h1>PHP, the time is now <?= date('Y-m-d H:i:s'); ?>, Host is <?= gethostname(); ?></h1>" > /var/www/html/index.php &&
    rm -f /var/www/html/index.html &&
    service apache2 start
  SH
  block_device_mappings =
    [{ device_name: '/dev/sda1', ebs: { volume_size: 8, volume_type: 'gp2'} }]

  resp = autoscaling.create_launch_configuration \
    launch_configuration_name: @launch_configuration_name, image_id: image_id,
    key_name: @key_name, security_groups: security_groups,
    user_data: Base64.encode64(user_data), instance_type: instance_type,
    block_device_mappings: block_device_mappings
end

def create_autoscaling_group
  raise '@launch_configuration_name missing' unless @launch_configuration_name
  min_size = 1
  max_size = 1
  desired_capacity = 1
  vpc_zone_identifier = get_vpc_public_subnets_ids.join(',')
  resp = autoscaling.create_auto_scaling_group \
    auto_scaling_group_name: @auto_scaling_group_name,
    launch_configuration_name: @launch_configuration_name,
    min_size: min_size, max_size: max_size, desired_capacity: desired_capacity,
    vpc_zone_identifier: vpc_zone_identifier
end

def run
  puts "Region: #{@region}"
  puts 'Creating security group...';       ap resp = create_security_group
  puts 'Creating launch configuration...'; ap resp = create_launch_configuration
  puts 'Creating autoscaling group...';    ap resp = create_autoscaling_group
end

def cleanup
  raise '@launch_configuration_name missing' unless @launch_configuration_name
  raise '@auto_scaling_group_name' unless @auto_scaling_group_name
  resp = autoscaling.update_auto_scaling_group \
    auto_scaling_group_name: @auto_scaling_group_name,
    min_size: 0, max_size: 0, desired_capacity: 0
  resp = autoscaling.delete_auto_scaling_group \
    auto_scaling_group_name: @auto_scaling_group_name
  resp = autoscaling.delete_launch_configuration \
    launch_configuration_name: @launch_configuration_name
  resp = ec2.delete_security_group group_name: 'autoscaling-sg'
  true
end
