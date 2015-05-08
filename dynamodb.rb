require './config'

def dynamodb
  @dynamodb ||= Aws::DynamoDB::Client.new(region: @region)
end

def create_table
  attribute_definitions = [{ attribute_name: 'GameTitle', attribute_type: 'S' },
                           { attribute_name: 'UserID',    attribute_type: 'N' }]
  key_schema =            [{ attribute_name: 'UserID',    key_type: 'HASH' },
                           { attribute_name: 'GameTitle', key_type: 'RANGE' }]
  provisioned_throughput = { read_capacity_units: 1, write_capacity_units: 1 }

  resp = dynamodb.create_table \
    table_name: @table_name, attribute_definitions: attribute_definitions,
    key_schema: key_schema, provisioned_throughput: provisioned_throughput
end

def create_table_waiter
  resp = dynamodb.wait_until :table_exists, table_name: @table_name
end

def put_items
  #        [ UserID,  GameTitle,        TopScore, Wins, Losses ]
  items = [[    101, 'Galaxy Invaders',     5842,   21,     72 ],
           [    101, 'Meteor Blasters',     1000,   12,     72 ],
           [    102, 'Alien Adventure',      192,   32,    192 ],
           [    102, 'Galaxy Invaders',        0,    0,      5 ]]

  items.each do |i|
    item = { UserID: i[0], GameTitle: i[1], TopScore: i[2], Wins: i[3], Losses: i[4] }
    resp = dynamodb.put_item table_name: @table_name, item: item
  end
  items
end

def update_items
  key = { UserID: 102, GameTitle: 'Galaxy Invaders' }
  attribute_updates = { Wins: { value: 1 } }
  resp = dynamodb.update_item \
    table_name: @table_name, key: key, attribute_updates: attribute_updates
end

def cleanup
  puts 'Deleting table...'
  ap dynamodb.delete_table table_name: @table_name
  puts 'Waiting for deletion...'
  ap dynamodb.wait_until :table_not_exists, table_name: @table_name
  true
end

def run
  puts "Region: #{@region}"
  puts 'Creating table...';    ap resp = create_table
  puts 'Waiting for table...'; ap resp = create_table_waiter
  puts 'Putting items...';     ap resp = put_items
  puts 'Updating items...';    ap resp = update_items
  true
end
