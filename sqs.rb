require 'parallel'
require './config'

def sqs
  @sqs = Aws::SQS::Client.new(region: @region)
end

def get_queue_url
  resp = sqs.list_queues queue_name_prefix: @queue_name
  @queue_url = resp[:queue_urls][0]
end

def create_queue
  raise '@queue_name missing' unless @queue_name
  attributes = { VisibilityTimeout: 30, MessageRetentionPeriod: 86400 }
  resp = sqs.create_queue \
    queue_name: @queue_name, attributes: stringify_values(attributes)
  @queue_url = resp[:queue_url]
  resp
end

def produce_messages
  raise '@queue_url missing' unless @queue_url
  start_time = current_time
  messages = (1..10).map { |i| "Message #{i}, Time: #{start_time}" }
  entries = messages.each_with_index.map { |m, i| { message_body: m, id: i.to_s } }
  resp = sqs.send_message_batch queue_url: @queue_url, entries: entries
end

def consume_messages
  raise '@queue_url missing' unless @queue_url
  wait_time_seconds = 20
  max_number_of_messages = 10
  resp = sqs.receive_message \
    queue_url: @queue_url, max_number_of_messages: max_number_of_messages,
    wait_time_seconds: wait_time_seconds
  messages = resp[:messages]
  entries = messages.each_with_index.map { |m, i| { id: i.to_s, receipt_handle: m[:receipt_handle] } }
  resp = sqs.delete_message_batch \
    queue_url: @queue_url, entries: entries unless entries.empty?
  messages
end

def view_messages
  raise '@queue_url missing' unless @queue_url
  visibility_timeout = 0
  wait_time_seconds = 3
  max_number_of_messages = 10
  resp = sqs.receive_message \
    queue_url: @queue_url, max_number_of_messages: max_number_of_messages,
    visibility_timeout: visibility_timeout, wait_time_seconds: wait_time_seconds
end

def purge_queue
  raise '@queue_url missing' unless @queue_url
  resp = sqs.purge_queue queue_url: @queue_url
end

def cleanup
  resp = sqs.list_queues queue_name_prefix: @queue_name
  queue_urls = resp[:queue_urls]
  queue_urls.each do |queue_url|
    resp = sqs.delete_queue queue_url: queue_url
  end
end

def stringify_values(h)
  h.map { |k, v| [k, v.to_s] }.to_h
end

def current_time
  Time.now.strftime('%H:%M:%S.%L')
end

def run_consumer_server
  raise '@queue_url missing' unless @queue_url
  threads = 5
  Parallel.map(1..threads, in_threads: threads) do |t|
    loop do
      messages = consume_messages
      messages.each do |m|
        print "Thread #{t} #{current_time} - #{m[:body]}\n"
      end
    end
  end
end

def run_producer_server
  raise '@queue_url missing' unless @queue_url
  threads = 2
  Parallel.map(1..threads, in_threads: threads) do |t|
    loop do
      resp = produce_messages
      print "#{current_time} #{resp[:successful].count} messages queued\n"
    end
  end
end

def run
  puts "Region: #{@region}"
  puts "Queue: #{@queue_name}"
  puts 'Creating queue...';     ap resp = create_queue
  puts 'Producing message...';  ap resp = produce_messages
  puts 'Viewing messages...';   ap resp = view_messages
  puts 'Consuming messages...'; ap resp = consume_messages
  true
end
