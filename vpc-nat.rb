require './config'

def ec2
  @ec2 ||= Aws::EC2::Client.new(region: @region)
end

def create_vpc
  cidr_block = '10.0.0.0/16'
  resp = ec2.create_vpc cidr_block: cidr_block
  @vpc_id = resp[:vpc][:vpc_id]
  resp
end

def configure_vpc_name
  raise '@vpc_id missing' unless @vpc_id
  resources = [@vpc_id]
  tags = [ { key: 'Name', value: 'myNATVPC'} ]
  resp = ec2.create_tags resources: resources, tags: tags
end

def create_route_table
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.create_route_table vpc_id: @vpc_id
  @route_table_id = resp[:route_table][:route_table_id]
  resp
end

def create_public_subnet
  cidr_block = '10.0.0.0/24'
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.create_subnet vpc_id: @vpc_id, cidr_block: cidr_block
  @public_subnet_id = resp[:subnet][:subnet_id]
  resp
end

def create_subnet_waiter
  raise '@public_subnet_id missing' unless @public_subnet_id
  raise '@private_subnet_id missing' unless @private_subnet_id
  resp = ec2.wait_until \
    :subnet_available, subnet_ids: [@public_subnet_id, @private_subnet_id]
end

def configure_public_subnet_name
  subnet_name = 'NAT public subnet'
  raise '@public_subnet_id missing' unless @public_subnet_id
  resources = [@public_subnet_id]
  tags = [ { key: 'Name', value: subnet_name } ]
  resp = ec2.create_tags resources: resources, tags: tags
end

def create_private_subnet
  cidr_block = '10.0.1.0/24'
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.create_subnet vpc_id: @vpc_id, cidr_block: cidr_block
  @private_subnet_id = resp[:subnet][:subnet_id]
  resp
end

def configure_private_subnet_name
  subnet_name = 'NAT private subnet'
  raise '@private_subnet_id missing' unless @private_subnet_id
  resources = [@private_subnet_id]
  tags = [ { key: 'Name', value: subnet_name } ]
  resp = ec2.create_tags resources: resources, tags: tags
end

def associate_route_table
  raise '@public_subnet_id missing' unless @public_subnet_id
  raise '@route_table_id missing' unless @route_table_id
  resp = ec2.associate_route_table \
    subnet_id: @public_subnet_id, route_table_id: @route_table_id
end

def create_internet_gateway
  resp = ec2.create_internet_gateway
  @internet_gateway_id = resp[:internet_gateway][:internet_gateway_id]
  resp
end

def attach_internet_gateway
  raise '@internet_gateway_id missing' unless @internet_gateway_id
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.attach_internet_gateway \
    internet_gateway_id: @internet_gateway_id, vpc_id: @vpc_id
end

def configure_routes
  raise '@route_table_id missing' unless @route_table_id
  raise '@internet_gateway_id missing' unless @internet_gateway_id
  destination_cidr_block = '0.0.0.0/0'
  resp = ec2.create_route \
    route_table_id: @route_table_id, gateway_id: @internet_gateway_id,
    destination_cidr_block: destination_cidr_block
end

def enable_dns_hostnames
  raise '@vpc_id missing' unless @vpc_id
  enable_dns_hostnames = { value: true }
  resp = ec2.modify_vpc_attribute \
    vpc_id: @vpc_id,
    enable_dns_hostnames: enable_dns_hostnames
end

def create_security_group
  group_name = 'NATSG'
  description = 'Ports 22/80/443/ICMP'
  resp = ec2.create_security_group \
    group_name: group_name, description: description, vpc_id: @vpc_id
  @group_id = resp[:group_id]
  resp
end

def authorize_security_group_ingress
  raise '@group_id missing' unless @group_id
  ip_permissions = [
    { ip_protocol: 'tcp',  from_port:  22, to_port:  22, ip_ranges: [cidr_ip: '0.0.0.0/0'  ] },
    { ip_protocol: 'tcp',  from_port:  80, to_port:  80, ip_ranges: [cidr_ip: '10.0.1.0/24'] },
    { ip_protocol: 'tcp',  from_port: 443, to_port: 443, ip_ranges: [cidr_ip: '10.0.1.0/24'] },
    { ip_protocol: 'icmp', from_port:  -1, to_port:  -1, ip_ranges: [cidr_ip: '0.0.0.0/0'  ] } ]
  resp = ec2.authorize_security_group_ingress \
    group_id: @group_id, ip_permissions: ip_permissions
end

def authorize_security_group_egress
  raise '@group_id missing' unless @group_id
  ip_permissions = [
    { ip_protocol: 'tcp',  from_port:  80, to_port:  80, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'tcp',  from_port: 443, to_port: 443, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'icmp', from_port:  -1, to_port:  -1, ip_ranges: [cidr_ip: '0.0.0.0/0'] } ]
  resp = ec2.authorize_security_group_egress \
    group_id: @group_id, ip_permissions: ip_permissions
end

def run_nat_instance
  image_id = get_ubuntu_image_id
  key_name = 'shai-aws-us'
  instance_type = 't2.micro'
  block_device_mappings =
    [{ device_name: '/dev/sda1', ebs: { volume_size: 8, volume_type: 'gp2'} }]

  # PAT script from gist is up to date as of May/2015. Original script from:
  # Image: amzn-ami-vpc-nat-hvm-2015.03.0.x86_64-gp2
  # Path: /usr/local/sbin/configure-pat.sh, md5sum: 9eef77b8c0967368b095b0b1c664c04c
  user_data = <<-SH.gsub(/^ +/, '')
    #!/bin/bash
    curl -L https://gist.github.com/natefox/9611189/raw/16426c676f9cb66bb59a6dc38d8f50f5449f3ad8/configure-pat.sh -o /usr/local/sbin/configure-pat.sh
    chmod +x /usr/local/sbin/configure-pat.sh
    echo "/usr/local/sbin/configure-pat.sh\nexit 0" > /etc/rc.local
    apt-get -yy install htop >> /var/log/cloud-init-output.log &
  SH

  resp = ec2.run_instances \
    image_id: image_id, key_name: key_name, security_group_ids: [@group_id],
    min_count: 1, max_count: 1, instance_type: instance_type,
    user_data: Base64.encode64(user_data), subnet_id: @public_subnet_id,
    block_device_mappings: block_device_mappings
  @instance_ids = resp[:instances].map { |i| i[:instance_id] }
  @network_interface_id = resp[:instances][0][:network_interfaces][0][:network_interface_id]
  @instance_id = @instance_ids.first
  resp
end

def run_nat_instance_waiter
  raise '@instance_id missing' unless @instance_id
  resp = ec2.wait_until :instance_running, instance_ids: [@instance_id]
end

def disable_source_dest_check
  raise '@instance_id missing' unless @instance_id
  source_dest_check = { value: false }
  resp = ec2.modify_instance_attribute \
    instance_id: @instance_id, source_dest_check: source_dest_check
end

def get_main_route_table_id
  raise '@vpc_id missing' unless @vpc_id
  filters = [ { name: 'vpc-id',           values: [@vpc_id] },
              { name: 'association.main', values: ['true']  } ]

  resp = ec2.describe_route_tables filters: filters
  @main_route_table_id = resp[:route_tables][0][:route_table_id]
  resp
end

def add_eni_route
  raise '@main_route_table_id missing' unless @main_route_table_id
  destination_cidr_block = '0.0.0.0/0'

  resp = ec2.create_route \
    route_table_id: @main_route_table_id,
    destination_cidr_block: destination_cidr_block,
    network_interface_id: @network_interface_id
end

def allocate_elastic_ip
  domain = 'vpc'
  resp = ec2.allocate_address domain: domain
  @allocation_id = resp[:allocation_id]
  resp
end

def associate_elastic_ip
  raise '@instance_id missing' unless @instance_id
  raise '@allocation_id missing' unless @allocation_id
  resp = ec2.associate_address \
    instance_id: @instance_id, allocation_id: @allocation_id
  @association_id = resp[:association_id]
  resp
end

def terminate_nat_instance
  raise '@instance_id missing' unless @instance_id
  resp = ec2.terminate_instances instance_ids: [@instance_id]
end

def terminate_nat_instance_waiter
  raise '@instance_id missing' unless @instance_id
  resp = ec2.wait_until :instance_terminated, instance_ids: [@instance_id]
end

def delete_security_group
  raise '@group_id missing' unless @group_id
  resp = ec2.delete_security_group group_id: @group_id
end

def release_elastic_ip
  raise '@allocation_id missing' unless @allocation_id
  resp = ec2.release_address allocation_id: @allocation_id
end

def delete_public_subnet
  raise '@public_subnet_id missing' unless @public_subnet_id
  resp = ec2.delete_subnet subnet_id: @public_subnet_id
end

def delete_private_subnet
  raise '@private_subnet_id missing' unless @private_subnet_id
  resp = ec2.delete_subnet subnet_id: @private_subnet_id
end

def delete_internet_gateway
  raise '@internet_gateway_id missing' unless @internet_gateway_id
  resp = ec2.delete_internet_gateway internet_gateway_id: @internet_gateway_id
end

def detach_internet_gateway
  raise '@internet_gateway_id missing' unless @internet_gateway_id
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.detach_internet_gateway \
    internet_gateway_id: @internet_gateway_id, vpc_id: @vpc_id
end

def delete_route_table
  raise '@route_table_id missing' unless @route_table_id
  resp = ec2.delete_route_table route_table_id: @route_table_id
end

def delete_vpc
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.delete_vpc vpc_id: @vpc_id
end

def cleanup
  puts 'Terminating NAT instance...';        ap resp = terminate_nat_instance
  puts 'Waiting for termination...';         ap resp = terminate_nat_instance_waiter
  puts 'Releasing elastic IP...';            ap resp = release_elastic_ip
  puts 'Deleting security group...';         ap resp = delete_security_group
  puts 'Detaching Internet gateway...';      ap resp = detach_internet_gateway
  puts 'Deleting Internet gateway...';       ap resp = delete_internet_gateway
  puts 'Deleting public subnet...';          ap resp = delete_public_subnet
  puts 'Deleting private subnet...';         ap resp = delete_private_subnet
  puts 'Deleting route table...';            ap resp = delete_route_table
  puts 'Deleting VPC...';                    ap resp = delete_vpc
  true
end

def run
  puts "Region: #{@region}"
  puts 'Creating VPC...';                    ap resp = create_vpc
  puts 'Configuring VPC name...';            ap resp = configure_vpc_name
  puts 'Creating route table...';            ap resp = create_route_table
  puts 'Creating public subnet...';          ap resp = create_public_subnet
  puts 'Creating private subnet...';         ap resp = create_private_subnet
  puts 'Waiting for subnets...';             ap resp = create_subnet_waiter
  puts 'Configuring public subnet name...';  ap resp = configure_public_subnet_name
  puts 'Configuring private subnet name...'; ap resp = configure_private_subnet_name
  puts 'Associating route table...';         ap resp = associate_route_table
  puts 'Creating Internet gateway...';       ap resp = create_internet_gateway
  puts 'Attaching Internet gateway...';      ap resp = attach_internet_gateway
  puts 'Configuring routes...';              ap resp = configure_routes
  puts 'Enabling DNS hostnames...';          ap resp = enable_dns_hostnames
  puts 'Creating security group...';         ap resp = create_security_group
  puts 'Adding security group ingress...';   ap resp = authorize_security_group_ingress
  puts 'Adding security group egress...';    ap resp = authorize_security_group_egress
  puts 'Running NAT instance...';            ap resp = run_nat_instance
  puts 'Disabling Source/Dest. Checks...';   ap resp = disable_source_dest_check
  puts 'Finding main route table...';        ap resp = get_main_route_table_id
  puts 'Adding ENI route...';                ap resp = add_eni_route
  puts 'Waiting for NAT instance...';        ap resp = run_nat_instance_waiter
  puts 'Allocating elastic IP...';           ap resp = allocate_elastic_ip
  puts 'Associating elastic IP...';          ap resp = associate_elastic_ip
  true
end
