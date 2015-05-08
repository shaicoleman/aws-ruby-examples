require './config'

def ec2
  @ec2 ||= Aws::EC2::Client.new(region: @region)
end

def create_key_pair
  key_filename = '~/.ssh/#{@key_name}'
  key_path = File.expand_path(key_filename)
  raise "Keypair already exists in #{key_path}" if File.exists?(key_path)
  resp = ec2.create_key_pair key_name: @key_name
  key_material = resp[:key_material]
  File.open(key_path, 'w') { |f| f.chmod 0600; f.puts key_material }
end

def create_security_group
  group_name = 'SSH/HTTP/HTTPS/ICMP'
  description = 'Ports 22/80/443/ICMP'
  ip_permissions = [
    { ip_protocol: 'tcp',  from_port: 22,  to_port: 22,  ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'tcp',  from_port: 80,  to_port: 80,  ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'tcp',  from_port: 443, to_port: 443, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'icmp', from_port: -1,  to_port: -1,  ip_ranges: [cidr_ip: '0.0.0.0/0'] } ]
  resp = ec2.create_security_group \
    group_name: group_name, description: description
  resp = ec2.authorize_security_group_ingress \
    group_name: group_name, ip_permissions: ip_permissions
end

def run_instance
  image_id = get_ubuntu_image_id
  security_groups = ['SSH/HTTP/HTTPS/ICMP']
  instance_type = 't2.micro'
  placement = { availability_zone: 'us-east-1e' }
  block_device_mappings =
    [{ device_name: '/dev/sda1', ebs: { volume_size: 8, volume_type: 'gp2'} }]
  resp = ec2.run_instances \
    image_id: image_id, key_name: @key_name, security_groups: security_groups,
    min_count: 1, max_count: 1, instance_type: instance_type,
    placement: placement, block_device_mappings: block_device_mappings
end
