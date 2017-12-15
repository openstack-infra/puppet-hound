require 'puppet-openstack_infra_spec_helper/spec_helper_acceptance'

describe 'puppet-hound:: manifest', :if => ['debian', 'ubuntu'].include?(os[:family]) do
  def pp_path
    base_path = File.dirname(__FILE__)
    File.join(base_path, 'fixtures')
  end

  def init_puppet_module
    module_path = File.join(pp_path, 'hound.pp')
    File.read(module_path)
  end

  it 'should work with no errors' do
    apply_manifest(init_puppet_module, catch_failures: true)
  end

end
