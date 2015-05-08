require './config'

def cloudfront
  @cloudfront ||= Aws::CloudFront::Client.new(region: @region)
end

def create_distribution
  caller_reference = 'mycloudfront'
  origin_id = 'S3-mytestbucket'
  origin_domain = 'mytestbucket.s3.amazonaws.com'
  origins = { quantity: 1, items: [ { id: origin_id, domain_name: origin_domain, origin_path: '',
                                      s3_origin_config: { origin_access_identity: '' } } ] }
  default_cache_behavior = {
    target_origin_id: origin_id,
    forwarded_values: { query_string: false, cookies: { forward: 'none' } },
    trusted_signers: { enabled: false, quantity: 0 },
    viewer_protocol_policy: 'allow-all',
    min_ttl: 0 }
  price_class = 'PriceClass_All'
  viewer_certificate = { cloud_front_default_certificate: true }
  comment = '-'
  enabled = true
  resp = cloudfront.create_distribution \
    distribution_config: {
      caller_reference: caller_reference,
      origins: origins,
      default_cache_behavior: default_cache_behavior,
      comment: comment,
      price_class: price_class,
      viewer_certificate: viewer_certificate,
      enabled: true }
  @distribution_id          = resp[:distribution][:id]
  @distribution_domain_name = resp[:distribution][:domain_name]
  resp
end

def create_distribution_waiter
  raise '@distribution_id missing' unless @distribution_id
  resp = cloudfront.wait_until :distribution_deployed, id: @distribution_id
end

def disable_distribution
  raise '@distribution_id missing' unless @distribution_id
  resp = get_distribution
  etag = resp[:etag]
  distribution_config = resp[:distribution][:distribution_config].to_hash
  distribution_config[:enabled] = false
  resp = cloudfront.update_distribution \
    id: @distribution_id, distribution_config: distribution_config, if_match: etag
end

def disable_distribution_waiter
  raise '@distribution_id missing' unless @distribution_id
  resp = cloudfront.wait_until :distribution_deployed, id: @distribution_id
end

def delete_distribution
  raise '@distribution_id missing' unless @distribution_id
  resp = get_distribution
  etag = resp[:etag]
  resp = cloudfront.delete_distribution id: @distribution_id, if_match: etag
end

def cleanup
  raise '@distribution_id missing' unless @distribution_id
  puts 'Disabling distribution...'; ap resp = disable_distribution
  puts 'Waiting until disabled...'; ap resp = disable_distribution_waiter
  puts 'Deleting distribution...';  ap resp = delete_distribution
  true
end

def run
  puts "Region: #{@region}"
  puts 'Creating distribution...';    ap resp = create_distribution
  puts 'Waiting for distribution...'; ap resp = create_distribution_waiter
  puts "CloudFront URL: https://#{@distribution_domain_name}/"
  true
end
