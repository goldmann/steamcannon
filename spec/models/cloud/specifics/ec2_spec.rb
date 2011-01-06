#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'spec_helper'

describe Cloud::Specifics::Ec2 do
  before(:each) do
    @cloud_profile = Factory.build(:cloud_profile,
                                   :username => 'username',
                                   :password => 'password')
    @ec2 = Cloud::Specifics::Ec2.new(@cloud_profile)
    @instance = Factory.build(:instance)
  end

  describe "multicast_config" do
    before(:each) do
      @ec2.stub!(:pre_signed_put_url).and_return('put_url')
      @ec2.stub!(:pre_signed_delete_url).and_return('delete_url')
    end

    it "should generate put_url" do
      @ec2.should_receive(:pre_signed_put_url).with(@instance)
      @ec2.multicast_config(@instance)
    end

    it "should generate delete_url" do
      @ec2.should_receive(:pre_signed_delete_url).with(@instance)
      @ec2.multicast_config(@instance)
    end

    it "should return put and delete urls" do
      expected = {
        :s3_ping => {
          :pre_signed_put_url => 'put_url',
          :pre_signed_delete_url => 'delete_url'
        }
      }
      @ec2.multicast_config(@instance).should == expected
    end
  end

  describe "launch_options" do
    before(:each) do
      @ec2.stub!(:base_security_group).and_return({:name => 'steamcannon_base'})
      @ec2.stub!(:service_security_groups).and_return([{:name => 'steamcannon_service'}])
      @ec2.stub!(:ensure_security_group)
    end

    it "should include base security group" do
      @ec2.should_receive(:base_security_group).and_return({})
      @ec2.launch_options(@instance)
    end

    it "should include service specific security groups" do
      @ec2.should_receive(:service_security_groups).with(@instance).and_return([])
      @ec2.launch_options(@instance)
    end

    it "should ensure security groups exist" do
      @ec2.should_receive(:ensure_security_group).with({:name => 'steamcannon_base'})
      @ec2.should_receive(:ensure_security_group).with({:name => 'steamcannon_service'})
      @ec2.launch_options(@instance)
    end

    it "should return security group names" do
      expected =  ['steamcannon_base', 'steamcannon_service']
      @ec2.launch_options(@instance)[:security_group].should == expected
    end

  end

  describe "running_instances" do
    it "should be empty if cloud username isn't set" do
      @cloud_profile.stub!(:username).and_return('')
      @ec2.running_instances.should be_empty
    end

    it "should be empty if cloud password isn't set" do
      @cloud_profile.stub!(:password).and_return('')
      @ec2.running_instances.should be_empty
    end
  end

  describe "pre_signed_put_url" do
    it "should have :put method" do
      @ec2.should_receive(:pre_signed_url).with(@instance, hash_including(:method => :put))
      @ec2.send(:pre_signed_put_url, @instance)
    end

    it "should have public-read permissions" do
      @ec2.should_receive(:pre_signed_url).
        with(@instance, hash_including(:headers => {'x-amz-acl' => 'public-read'}))
      @ec2.send(:pre_signed_put_url, @instance)
    end
  end

  describe "pre_signed_delete_url" do
    it "should have :delete method" do
      @ec2.should_receive(:pre_signed_url).with(@instance, hash_including(:method => :delete))
      @ec2.send(:pre_signed_delete_url, @instance)
    end
  end

  describe "pre_signed_url" do
    before(:each) do
      @ec2.stub!(:multicast_bucket).and_return('bucket')
      @created_at = Time.now
      @instance.stub!(:created_at).and_return(@created_at)
      @sig = S3::Signature
      @sig.stub!(:generate_temporary_url)
    end

    it "should get access_key from cloud_profile object" do
      @cloud_profile.should_receive(:username).and_return('username')
      @sig.should_receive(:generate_temporary_url).
        with(hash_including(:access_key => 'username'))
      @ec2.send(:pre_signed_url, @instance, {})
    end

    it "should get secret_access_key from cloud_profile object" do
      @cloud_profile.should_receive(:password).and_return('password')
      @sig.should_receive(:generate_temporary_url).
        with(hash_including(:secret_access_key => 'password'))
      @ec2.send(:pre_signed_url, @instance, {})
    end

    it "should get multicast bucket" do
      @ec2.should_receive(:multicast_bucket).and_return('bucket')
      @sig.should_receive(:generate_temporary_url).
        with(hash_including(:bucket => 'bucket'))
      @ec2.send(:pre_signed_url, @instance, {})
    end

    it "should expire 1 year after instance creation" do
      expires_at = @created_at + 1.year
      @instance.should_receive(:created_at).and_return(@created_at)
      @sig.should_receive(:generate_temporary_url).
        with(hash_including(:expires_at => expires_at))
      @ec2.send(:pre_signed_url, @instance, {})
    end

    it "should return temporary url" do
      @sig.should_receive(:generate_temporary_url).and_return('url')
      @ec2.send(:pre_signed_url, @instance, {}).should == 'url'
    end
  end

  describe "multicast_bucket" do
    before(:each) do
      @s3 = Aws::S3
      @s3.stub!(:new)
      @s3::Bucket.stub(:create)
    end

    it "should generate suffix from username and ca certificate" do
      ca_certificate = Factory(:certificate)
      Certificate.should_receive(:ca_certificate).and_return(ca_certificate)
      ca_certificate.should_receive(:certificate).and_return('certificate')
      Digest::SHA1.should_receive(:hexdigest).with('username')
      Digest::SHA1.should_receive(:hexdigest).with('certificate')
      Digest::SHA1.should_receive(:hexdigest).and_return('hexdigest')
      @ec2.send(:multicast_bucket)
    end

    it "should create a new s3 object" do
      @s3.should_receive(:new).with('username', 'password')
      @ec2.send(:multicast_bucket)
    end

    it "should create s3 bucket with public read permissions" do
      @s3::Bucket.should_receive(:create).with(anything, anything, true, 'public-read')
      @ec2.send(:multicast_bucket)
    end

    it "should return bucket name" do
      Digest::SHA1.stub!(:hexdigest).and_return('suffix')
      @ec2.send(:multicast_bucket).should == "SteamCannonEnvironments_suffix"
    end
  end

  describe "base_security_group" do
    it "should be named steamcannon" do
      @ec2.send(:base_security_group)[:name].should == 'steamcannon'
    end

    it "should have permissions inside group" do
      permissions = @ec2.send(:base_security_group)[:permissions]
      permissions.should include(:self)
    end

    it "should have permissions for ssh" do
      permissions = @ec2.send(:base_security_group)[:permissions]
      permissions.find do |permission|
        permission.is_a?(Hash) and permission[:from_port] == '22'
      end.should_not be_nil
    end

    it "should have permissions for Agent" do
      permissions = @ec2.send(:base_security_group)[:permissions]
      permissions.find do |permission|
        permission.is_a?(Hash) and permission[:from_port] == '7575'
      end.should_not be_nil
    end
  end

  describe "service_security_groups" do
    it "should retrieve all agent services" do
      @ec2.should_receive(:agent_services).and_return([])
      @ec2.send(:service_security_groups, @instance)
    end

    it "should create security group from each service" do
      agent_service = mock('agent service')
      @ec2.stub!(:agent_services).and_return([agent_service])
      @ec2.should_receive(:security_group_from_service).with(agent_service).and_return('group')
      @ec2.send(:service_security_groups, @instance).should == ['group']
    end
  end

  describe "security_group_from_service" do
    before(:each) do
      @service = Factory.build(:service)
      @agent_service = mock('agent_service',
                            :service => @service,
                            :open_ports => [])
    end

    it "should belong to correct cloud_profile" do
      @ec2.send(:security_group_from_service, @agent_service)[:cloud_profile].should == @cloud_profile
    end

    it "should create name from service's name" do
      @service.should_receive(:name).and_return('name')
      @ec2.send(:security_group_from_service, @agent_service)[:name].should match(/name/)
    end

    it "should create description from service's full name" do
      @service.should_receive(:full_name).and_return('full name')
      @ec2.send(:security_group_from_service, @agent_service)[:description].should match(/full name/)
    end

    it "should create permission for every open port" do
      @agent_service.should_receive(:open_ports).and_return([80])
      permissions = @ec2.send(:security_group_from_service, @agent_service)[:permissions]
      permissions.size.should be(1)
      permissions.first[:to_port].should be(80)
      permissions.first[:from_port].should be(80)
    end
  end

  describe "agent_services" do
    it "should do create instance for service" do
      service = Factory.build(:service)
      @instance.stub_chain(:image, :services).and_return([service])
      AgentServices::Base.should_receive(:instance_for_service).
        with(service, @instance.environment)
      @ec2.send(:agent_services, @instance)
    end
  end
  
  describe 'instance_run_cost' do
    it "should calculate a per hour cost" do
      @ec2.instance_run_cost(120, 't1.micro', 'us-east-1').should == 0.04
    end

    it "should count partial hours" do
      @ec2.instance_run_cost(121, 't1.micro', 'us-east-1').should == 0.06
    end

    it "should return 0.0 if minutes is nil" do
      @ec2.instance_run_cost(nil, 't1.micro', 'us-east-1').should == 0.0
    end

    it "should return 0.0 if profile does not exist" do
      @ec2.instance_run_cost(120, 'x1.micro', 'us-east-1').should == 0.0
    end
    
  end

  describe 'cloud registration' do
    it "should be registered" do
      Cloud::Specifics::Base.available_clouds.keys.should include(:ec2)
    end

    it "should include the name" do
      Cloud::Specifics::Base.available_clouds[:ec2][:name].should == :ec2
    end

    it "should include the display name" do
      Cloud::Specifics::Base.available_clouds[:ec2][:display_name].should == 'Amazon EC2'
    end
    
    it "should include its regions as providers" do
      providers = Cloud::Specifics::Base.available_clouds[:ec2][:providers]
      %w{ us-east-1 us-west-1 eu-west-1 ap-southeast-1 }.each do |region|
        providers.should include(region)
      end
    end
  end
end
