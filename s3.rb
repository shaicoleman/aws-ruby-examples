require './config'

def s3
  @s3 ||= Aws::S3::Client.new(region: @region)
end

def create_bucket
  @bucket = "s3-test-#{random_id}"
  acl = 'public-read'
  resp = s3.create_bucket acl: acl, bucket: @bucket
end

def enable_versioning
  versioning_configuration = { mfa_delete: 'Disabled', status: 'Enabled' }
  resp = s3.put_bucket_versioning \
    bucket: @bucket, versioning_configuration: versioning_configuration
end

def upload_file
  @key = 'index.html'
  acl = 'public-read'
  content_type = 'text/html'
  body = '<h1>Hello World</h1>'
  resp = s3.put_object \
    acl: acl, bucket: @bucket, key: @key, content_type: content_type, body: body
end

def get_object
  resp = s3.get_object bucket: @bucket, key: @key
end

def enable_website
  website_configuration = { index_document: { suffix: 'index.html' } }
  resp = s3.put_bucket_website \
    bucket: @bucket, website_configuration: website_configuration
end

def cleanup
  resp = s3.list_buckets
  bucket_names = resp[:buckets].map{ |b| b[:name] }
  test_buckets = bucket_names.grep(/^s3-test-/)
  puts "Deleting buckets: #{test_buckets.join(', ')}"
  test_buckets.each do |bucket|
    resp = s3.list_object_versions bucket: bucket
    object_versions = resp[:versions].map { |o| { key: o[:key], version_id: o[:version_id] } }
    # Delete is limited to 1000 objects
    resp = s3.delete_objects bucket: bucket, delete: { objects: object_versions } unless object_versions.empty?
    s3.delete_bucket bucket: bucket
  end
  test_buckets
end

def run
  puts "Region: #{@region}"
  puts "Bucket: #{@bucket}"

  puts 'Creating bucket...';     ap resp = create_bucket
  puts 'Enabling versioning...'; ap resp = enable_versioning
  puts 'Uploading file...';      ap resp = upload_file
  puts 'Getting file...';        ap resp = get_object
  puts 'Enabling website...';    ap resp = enable_website
  puts "File URL: https://#{@bucket}.s3.amazonaws.com/index.html"
  puts "Website URL: http://#{@bucket}.s3-website-#{@region}.amazonaws.com/"
  true
end
