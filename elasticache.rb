require './config'

def ec2
  @ec2 ||= Aws::EC2::Client.new(region: @region)
end

def elasticache
  @elasticache ||= Aws::ElastiCache::Client.new(region: @region)
end

def create_security_group
  group_name = 'Redis/ICMP'
  description = 'Ports 6379/ICMP'
  ip_permissions = [
    { ip_protocol: 'tcp',  from_port: 6379, to_port: 6379, ip_ranges: [cidr_ip: '0.0.0.0/0'] },
    { ip_protocol: 'icmp', from_port:   -1, to_port:   -1, ip_ranges: [cidr_ip: '0.0.0.0/0'] } ]
  resp = ec2.create_security_group \
    group_name: group_name, description: description
  @group_id = resp[:group_id]
  resp = ec2.authorize_security_group_ingress \
    group_name: group_name, ip_permissions: ip_permissions
end

def create_cache_cluster
  raise '@group_id' unless @group_id
  raise '@cache_cluster_id' unless @cache_cluster_id
  cache_node_type = 'cache.t2.micro'
  engine = 'redis'
  num_cache_nodes = 1
  security_group_ids = [@group_id]

  resp = elasticache.create_cache_cluster \
    cache_cluster_id: @cache_cluster_id, cache_node_type: cache_node_type,
    engine: engine, num_cache_nodes: num_cache_nodes,
    security_group_ids: security_group_ids
end

def cleanup
  resp = ec2.delete_security_group group_name: 'Redis/ICMP'
  raise '@cache_cluster_id' unless @cache_cluster_id
  resp = elasticache.delete_cache_cluster cache_cluster_id: @cache_cluster_id
  true
end

def run
  puts "Region: #{@region}"
  puts 'Creating security group...';      ap resp = create_security_group
  puts 'Creating cache cluster......';    ap resp = create_cache_cluster
  true
end
