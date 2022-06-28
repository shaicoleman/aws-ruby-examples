require './config'
require 'aws-sdk-ec2'
require 'yaml'

def main
  initialize_client
  get_instance_types
end

def initialize_client
  @ec2 = Aws::EC2::Client.new(region: @region)
end

def get_instance_types
  filters = [{ name: 'current-generation', values: ['true']},
            { name: 'hypervisor', values: ['nitro']}]
  parsed = []
  result = @ec2.describe_instance_types(filters: filters).each do |response|
    response.instance_types.each do
      parsed << { 
        instance_type: _1.instance_type,
        arch: _1.processor_info.supported_architectures.first,
        ram_gb: (_1.memory_info.size_in_mi_b / 1024.0).round,
        vcpus: _1.v_cpu_info.default_v_cpus
      }
    end
  end
  parsed.sort_by! { [_1[:arch], _1[:instance_type].gsub(/\..*$/, ''), _1[:ram_gb]] }

  File.write('instance_types.yml', YAML.dump(parsed))
end

main
