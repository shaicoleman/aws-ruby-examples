require './config'

def cloudformation
  @cloudformation ||= Aws::CloudFormation::Client.new(region: @region)
end

def create_stack
  raise '@stack_name missing' unless @stack_name
  template_url = 'https://s3.amazonaws.com/cloudformation-templates-us-east-1/WordPress_Single_Instance.template'
  @db_name          = 'wordpressdb'
  @db_user          = 'wordpressdb'
  @db_password      = random_token
  @db_root_password = random_token
  parameters = [
    { parameter_key: 'DBName',         parameter_value: @db_name },
    { parameter_key: 'DBPassword',     parameter_value: @db_password },
    { parameter_key: 'DBRootPassword', parameter_value: @db_root_password },
    { parameter_key: 'DBUser',         parameter_value: @db_user },
    { parameter_key: 'InstanceType',   parameter_value: 't2.micro' },
    { parameter_key: 'KeyName',        parameter_value: @key_name },
    { parameter_key: 'SSHLocation',    parameter_value: '0.0.0.0/0' } ]
  on_failure = 'DO_NOTHING'
  resp = cloudformation.create_stack \
    stack_name: @stack_name, template_url: template_url,
    parameters: parameters, on_failure: on_failure
end

def create_stack_waiter
  resp = cloudformation.wait_until :stack_create_complete, stack_name: @stack_name
  @website_url = resp[:stacks][0][:outputs].find { |o| o[:output_key] == 'WebsiteURL' }[:output_value]
  resp
end

def delete_stack
  resp = cloudformation.delete_stack stack_name: @stack_name
end

def delete_stack_waiter
  resp = cloudformation.wait_until :stack_delete_complete, stack_name: @stack_name
end

def cleanup
  puts 'Deleting stack...';       ap resp = delete_stack
  puts 'Waiting for deletion...'; ap resp = delete_stack_waiter
  true
end

def run
  puts "Region: #{@region}"
  puts 'Creating stack...';       ap resp = create_stack
  puts 'Waiting for creation...'; ap resp = create_stack_waiter
  puts "DB Name: #{@db_name}"
  puts "DB User: #{@db_user}"
  puts "DB Password: #{@db_password}"
  puts "DB Root Password: #{@db_root_password}"
  puts "WordPress will be available on #{@website_url}"
  true
end
