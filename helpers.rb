require 'open-uri'
require 'securerandom'

UBUNTU_VERSION = '14.04'
UBUNTU_CODENAME = 'trusty'

# Current generations instances, updated May/2015
INSTANCE_TYPES = %w(
  t2.micro t2.small t2.medium m3.medium m3.large m3.xlarge m3.2xlarge c4.large
  c4.xlarge c4.2xlarge c4.4xlarge c4.8xlarge c3.large c3.xlarge c3.2xlarge
  c3.4xlarge c3.8xlarge g2.2xlarge g2.8xlarge r3.large r3.xlarge r3.2xlarge
  r3.4xlarge r3.8xlarge i2.xlarge i2.2xlarge i2.4xlarge i2.8xlarge d2.xlarge
  d2.2xlarge d2.4xlarge d2.8xlarge)

# read dynamically from the pricing JSON
# Note that Amazon does not guarantee the availability or accuracy of the URL below
def instance_types
  pricing = open('http://a0.awsstatic.com/pricing/1/ec2/linux-od.min.js').read
  pricing.scan(/size:"([^"]+)"/).uniq
end

def random_id
  SecureRandom.base64(64).delete('+/=')[0,6].downcase
end

def random_token
  SecureRandom.base64(64).delete('+/=')[0,22]
end

def get_ubuntu_image_id
  raise '@region missing' unless @region
  url = "https://cloud-images.ubuntu.com/query/#{UBUNTU_CODENAME}/server/released.current.txt"
  releases = open(url).read
  releases.match(/^.*\tebs-ssd\tamd64\t#{@region}\t(\S+)\t+hvm$/)[1]
end

def get_ubuntu_image_id_alt
  owners  = ['099720109477'] # Canonical (Ubuntu)
  name    = "ubuntu/images/hvm-ssd/ubuntu-#{UBUNTU_CODENAME}-#{UBUNTU_VERSION}-amd64-server-*"
  filters = [{ name: 'name', values: [name] }]
  resp = ec2.describe_images owners: owners, filters: filters
  resp[:images].max_by { |x| x[:name] }.image_id
end

def cfn_instance_type_to_arch
  INSTANCE_TYPES.map { |a| { a => { 'Arch' => 'HVM64' } } }
end

def cfn_ubuntu_region_arch_to_ami
  url = "https://cloud-images.ubuntu.com/query/#{UBUNTU_CODENAME}/server/released.current.txt"
  releases = open(url).read
  region_image_ids = releases.scan(/^.*\tebs-ssd\tamd64\t(\S+)\t(\S+)\t+hvm$/)
  region_image_ids.map { |r| { r[0] => { 'HVM64' => r[1] } } }
end

def get_region_from_config
  aws_config_content = File.read(File.expand_path('~/.aws/config'))
  aws_config_content.match(/^\s*region\s*=\s*(\S+)\s*$/)[1]
end

def get_amazon_linux_image_id
  owners  = ['137112412989'] # Amazon
  filters = [{ name: 'name', values: ['amzn-ami-hvm-*'] }]
  resp = ec2.describe_images owners: owners, filters: filters
  images = resp[:images].find_all { |x| x[:name].match(/[\d.]{9,}.x86_64-gp2/) }
  images.max_by { |x| x[:name] }.image_id
end
