require 'spec_helper'
describe 'nubis_prometheus' do
  context 'with default values for all parameters' do
    it { should contain_class('nubis_prometheus') }
  end
end
