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
  tags = [ { key: 'Name', value: 'myVPC'} ]
  resp = ec2.create_tags resources: resources, tags: tags
end

def create_route_table
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.create_route_table vpc_id: @vpc_id
  @route_table_id = resp[:route_table][:route_table_id]
  resp
end

def create_public_subnet
  raise '@vpc_id missing' unless @vpc_id
  resp = ec2.create_subnet vpc_id: @vpc_id, cidr_block: '10.0.0.0/24'
  @availability_zone = resp[:subnet][:availability_zone]
  @subnet_id = resp[:subnet][:subnet_id]
  resp
end

def configure_public_subnet_name
  raise '@subnet_id missing' unless @subnet_id
  resources = [@subnet_id]
  tags = [ { key: 'Name', value: 'Public subnet'} ]
  resp = ec2.create_tags resources: resources, tags: tags
end

def associate_route_table
  raise '@subnet_id missing' unless @subnet_id
  raise '@route_table_id missing' unless @route_table_id
  resp = ec2.associate_route_table \
    subnet_id: @subnet_id, route_table_id: @route_table_id
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

def delete_public_subnet
  raise '@subnet_id missing' unless @subnet_id
  resp = ec2.delete_subnet subnet_id: @subnet_id
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
  puts 'Detaching Internet gateway...';     ap resp = detach_internet_gateway
  puts 'Deleting Internet gateway...';      ap resp = delete_internet_gateway
  puts 'Deleting public subnet...';         ap resp = delete_public_subnet
  puts 'Deleting route table...';           ap resp = delete_route_table
  puts 'Deleting VPC...';                   ap resp = delete_vpc
  true
end

def run
  puts "Region: #{@region}"
  puts 'Creating VPC...';                   ap resp = create_vpc
  puts 'Configuring VPC name...';           ap resp = configure_vpc_name
  puts 'Creating route table...';           ap resp = create_route_table
  puts 'Creating public subnet...';         ap resp = create_public_subnet
  puts 'Configuring public subnet name...'; ap resp = configure_public_subnet_name
  puts 'Associating route table...';        ap resp = associate_route_table
  puts 'Creating Internet gateway...';      ap resp = create_internet_gateway
  puts 'Attaching Internet gateway...';     ap resp = attach_internet_gateway
  puts 'Configuring routes...';             ap resp = configure_routes
  puts 'Enabling DNS hostnames...';         ap resp = enable_dns_hostnames
  true
end
