require './config'

def ec2
  @ec2 ||= Aws::EC2::Client.new(region: @region)
end

def create_security_group
  group_name = 'SSH/HTTP/HTTPS/ICMP'
  description = 'Ports 22/80/443/ICMP'
  ip_permissions = [
    { ip_protocol: 'tcp',  from_port:  22, to_port:  22, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'tcp',  from_port:  80, to_port:  80, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'tcp',  from_port: 443, to_port: 443, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'icmp', from_port:  -1, to_port:  -1, ip_ranges: [cidr_ip: '0.0.0.0/0'] } ]
  resp = ec2.create_security_group \
    group_name: group_name, description: description
  resp = ec2.authorize_security_group_ingress \
    group_name: group_name, ip_permissions: ip_permissions
end

def get_lowest_spot_price
  instance_types = ['m3.medium']
  product_descriptions = ['Linux/UNIX']
  start_time = Time.now
  end_time = Time.now
  resp = ec2.describe_spot_price_history \
    instance_types: instance_types, start_time: start_time, end_time: end_time,
    product_descriptions: product_descriptions
  ap resp
  price_item = resp[:spot_price_history].min_by { |s| BigDecimal.new(s[:spot_price]) }
  @spot_availability_zone = price_item[:availability_zone]
  @spot_price = price_item[:spot_price]
  @spot_price
end

def request_spot_instances
  instance_count = 1
  type = 'one-time'
  on_demand_price = '0.07'
  spot_price = @spot_price
  raise 'Spot price currently higher than on-demand' if BigDecimal.new(spot_price) > BigDecimal.new(on_demand_price)
  block_device_mappings =
    [{ device_name: '/dev/sda1', ebs: { volume_size: 8, volume_type: 'gp2'} }]
  launch_specification = {
    image_id: get_ubuntu_image_id,
    placement: { availability_zone: @spot_availability_zone },
    key_name: @key_name,
    security_groups: ['SSH/HTTP/HTTPS/ICMP'],
    instance_type: 'm3.medium',
    block_device_mappings: block_device_mappings }

  resp = ec2.request_spot_instances \
    instance_count: instance_count, type: type,
    spot_price: spot_price, launch_specification: launch_specification

  ap resp
  @spot_instance_request_id = resp[:spot_instance_requests][0][:spot_instance_request_id]
  @spot_instance_request_id
end
