require './config'

def ec2
  @ec2 ||= Aws::EC2::Client.new(region: @region)
end

def create_volume
  volume_type = 'gp2'
  size = 1
  resp = ec2.create_volume \
    size: size, availability_zone: @availability_zone, volume_type: volume_type
  ap resp
end

def attach_volume
  device = '/dev/sda2'
  resp = ec2.attach_volume \
    volume_id: @volume_id, instance_id: @instance_id, device: device
  ap resp
end

def detach_volume
  resp = ec2.detach_volume volume_id: @volume_id, force: true
  ap resp
end

def snapshot_volume
  description = 'lab ebs volume snapshot'
  resp = ec2.create_snapshot volume_id: @volume_id, description: description
  ap resp
end

def create_volume_from_snapshot
  volume_type = 'gp2'
  size = 8
  resp = ec2.create_volume \
    size: size, availability_zone: @availability_zone, volume_type: volume_type
  ap resp
end

