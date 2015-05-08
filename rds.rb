require './config'

def rds
  @rds ||= Aws::RDS::Client.new(region: @region)
end

def create_db_instance
  db_name = ''
  allocated_storage = 5
  db_instance_class = 'db.t2.micro'
  @db_instance_identifier = 'rdslab'
  @master_username = 'root'
  @master_user_password = random_token
  engine = 'mysql'
  storage_type = 'gp2'
  backup_retention_period = 0
  resp = rds.create_db_instance \
    engine: engine, db_instance_class: db_instance_class,
    allocated_storage: allocated_storage, storage_type: storage_type,
    db_instance_identifier: @db_instance_identifier,
    backup_retention_period: backup_retention_period,
    master_username: @master_username, master_user_password: @master_user_password
end

def create_db_instance_waiter
  raise '@db_instance_identifier missing' unless @db_instance_identifier
  resp = rds.wait_until \
    :db_instance_available, db_instance_identifier: @db_instance_identifier
  @endpoint_address = resp[:db_instances][0][:endpoint][:address]
  @endpoint_port    = resp[:db_instances][0][:endpoint][:port]
  resp
end

def delete_db_instance
  raise '@db_instance_identifier missing' unless @db_instance_identifier
  resp = rds.delete_db_instance \
    db_instance_identifier: @db_instance_identifier, skip_final_snapshot: true
end

def delete_db_instance_waiter
  raise '@db_instance_identifier missing' unless @db_instance_identifier
  resp = rds.wait_until \
    :db_instance_deleted, db_instance_identifier: @db_instance_identifier
  true
end

def cleanup
  puts 'Deleting DB instance...'; ap resp = delete_db_instance
  puts 'Waiting for deletion...'; ap resp = delete_db_instance_waiter
  true
end

def run
  puts "Region: #{@region}"
  puts 'Creating database...';    ap resp = create_db_instance
  puts 'Waiting for database...'; ap resp = create_db_instance_waiter
  puts "Host: #{@endpoint_address}"
  puts "Port: #{@endpoint_port}"
  puts "Master Username: #{@master_username}"
  puts "Master User Password: #{@master_user_password}"
  puts "mysql command-line: mysql -h #{@endpoint_address} -u #{@master_username} -p#{@master_user_password}"
  true
end
