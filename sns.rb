require './config'

def sns
  @sns = Aws::SNS::Client.new(region: @region)
end

# idempotent
def create_topic
  resp = sns.create_topic name: @topic_name
  @topic_arn = resp[:topic_arn]
  resp
end

def subscribe_email
  resp = sns.subscribe \
    topic_arn: @topic_arn, protocol: 'email', endpoint: @email
end

def set_display_name
  resp = sns.set_topic_attributes \
    topic_arn: @topic_arn, attribute_name: 'DisplayName',
    attribute_value: @display_name
end

def subscribe_sms
  resp = sns.subscribe \
    topic_arn: @topic_arn, protocol: 'sms', endpoint: @phone.delete('^0-9')
end

def subscribe_http
  resp = sns.subscribe \
    topic_arn: @topic_arn, protocol: 'http', endpoint: @http_endpoint
end

def subscribe_sqs
  resp = sns.subscribe \
    topic_arn: @topic_arn, protocol: 'sqs', endpoint: @queue_arn
end

def publish
  subject = 'This is a subject'
  message = 'This is a test'
  resp = sns.publish topic_arn: @topic_arn, subject: subject, message: message
end

def cleanup
  resp = sns.delete_topic topic_arn: @topic_arn
  true
end

def run
  puts "Region: #{@region}"
  puts "Topic: #{@topic_name}"
  puts 'Creating topic...';     ap resp = create_topic
  true
end
