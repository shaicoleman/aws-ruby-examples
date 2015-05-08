require './config'

def opsworks
  @opsworks ||= Aws::OpsWorks::Client.new(region: @region)
end

def create_stack
  stack_name = 'MyStack'
  default_os = 'Ubuntu 14.04 LTS'
  service_role_arn = 'arn:aws:iam::XXXXXXXXXXXX:role/aws-opsworks-service-role'
  default_instance_profile_arn = 'arn:aws:iam::XXXXXXXXXXXX:instance-profile/aws-opsworks-ec2-role'
  default_root_device_type = 'ebs'
  configuration_manager = { name: 'Chef', version: '11.10' }
  resp = opsworks.create_stack \
    name: stack_name, region: @region, default_ssh_key_name: @key_name,
    service_role_arn: service_role_arn,
    default_root_device_type: default_root_device_type,
    default_instance_profile_arn: default_instance_profile_arn,
    default_os: default_os, configuration_manager: configuration_manager
  ap resp
  @stack_id = resp[:stack_id]
  @stack_id
end

def add_layer
  raise '@stack_id missing' unless @stack_id
  type = 'php-app'
  name = 'PHP App Server'
  shortname = 'php-app'
  resp = opsworks.create_layer \
    stack_id: @stack_id, type: type, name: name, shortname: shortname
  ap resp
  @layer_id = resp[:layer_id]
  @layer_id
end

def add_instance
  raise '@stack_id missing' unless @stack_id
  raise '@layer_id missing' unless @layer_id
  instance_type = 't2.micro'

  resp = opsworks.create_instance \
    stack_id: @stack_id, layer_ids: [@layer_id], instance_type: instance_type
  ap resp
  @instance_id = resp[:instance_id]
  @instance_id
end

def add_app
  raise '@stack_id missing' unless @stack_id
  shortname = 'simplephpapp'
  name = 'SimplePHPApp'
  type = 'php'
  data_sources = []
  app_source = { url: 'https://github.com/amazonwebservices/opsworks-demo-php-simple-app.git',
                 type: 'git', revision: 'version1' }
  resp = opsworks.create_app \
    stack_id: @stack_id, type: type, shortname: shortname, name: name,
    app_source: app_source, data_sources: data_sources
  ap resp
  @app_id = resp[:app_id]
  @app_id
end

def start_instance
  raise '@instance_id missing' unless @instance_id
  resp = opsworks.start_instance instance_id: @instance_id
  ap resp
  true
end

def update_app
  raise '@app_id missing' unless @app_id
  app_source = { url: 'https://github.com/amazonwebservices/opsworks-demo-php-simple-app.git',
                 type: 'git', revision: 'version2' }
  attributes = { DocumentRoot: 'web' }
  resp = opsworks.update_app app_id: @app_id, app_source: app_source, attributes: attributes
  ap resp
  @app_id
end

def deploy
  raise '@stack_id missing' unless @stack_id
  raise '@app_id missing' unless @app_id
  raise '@instance_id missing' unless @instance_id

  command = { name: 'deploy' }

  resp = opsworks.create_deployment \
    stack_id: @stack_id, app_id: @app_id, instance_ids: [@instance_id], command: command
  ap resp
  @deployment_id = resp[:deployment_id]
  @deployment_id
end

def cleanup
  raise '@stack_id missing' unless @stack_id
  resp = opsworks.delete_instance instance_id: @instance_id if @instance_id
  resp = opsworks.delete_app app_id: @app_id if @app_id
  resp = opsworks.stop_stack stack_id: @stack_id
  resp = opsworks.delete_stack stack_id: @stack_id
  true
end
