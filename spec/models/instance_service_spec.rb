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

describe InstanceService do
  it { should belong_to :instance }
  it { should belong_to :service }
  it { should have_many :deployment_instance_services }
  it { should have_many :deployments }

  before(:each) do
    @instance_service = Factory(:instance_service)
    @mock_agent_service = mock('agent_service')
  end

  it "agent_service should lookup the agent service" do
    AgentServices::Base.should_receive(:instance_for_service).with(@instance_service.service,
                                                                   @instance_service.instance.environment)
    @instance_service.agent_service
  end

  it "should lookup url from agent_service" do
    agent_service = mock('agent_service')
    @instance_service.should_receive(:agent_service).and_return(agent_service)
    agent_service.should_receive(:url_for_instance_service).with(@instance_service)
    @instance_service.url
  end

  it "should return name from service" do
    service = mock('service')
    @instance_service.should_receive(:service).and_return(service)
    service.should_receive(:name).and_return('name')
    @instance_service.name.should == 'name'
  end

  it "should return full_name from service" do
    service = mock('service')
    @instance_service.should_receive(:service).and_return(service)
    service.should_receive(:full_name).and_return('full_name')
    @instance_service.full_name.should == 'full_name'
  end

  context 'states' do
    describe 'configure!' do
      %w{ pending configuring verifying running }.each do |state|
        it "should be able to move to :configuring from :#{state}" do
          @instance_service.current_state = state
          lambda {
            @instance_service.configure!
          }.should_not raise_error(AASM::InvalidTransition)
          @instance_service.current_state.should == 'configuring'
        end
      end
    end
  end

  describe 'configure_service' do
    before(:each) do
      @mock_agent_service.stub!(:configure_instance_service).and_return(true)
      @instance_service.stub!(:agent_service).and_return(@mock_agent_service)
      @instance_service.current_state = 'configuring'
    end

    it 'should delegate configure to the agent service' do
      @mock_agent_service.should_receive(:configure_instance_service).with(@instance_service).and_return(true)
      @instance_service.should_receive(:agent_service).and_return(@mock_agent_service)
      @instance_service.configure_service
    end

    it "should verify! if configuration occurred" do
      @instance_service.should_receive(:verify!)
      @instance_service.configure_service
    end

    it "should not change state if the configuration does not occur" do
      @mock_agent_service.should_receive(:configure_instance_service).with(@instance_service).and_return(false)
      @instance_service.should_not_receive(:verify!)
      @instance_service.configure_service
    end

    it "should fail! if its stuck in :configuring too long" do
      @mock_agent_service.stub!(:configure_instance_service).and_return(false)
      @instance_service.should_receive(:stuck_in_state_for_too_long?).and_return(true)
      @instance_service.should_receive(:fail!)
      @instance_service.configure_service
    end

    it "should not configure if there are any !:running required services" do
      @instance_service.should_receive(:required_services_running?).and_return(false)
      @mock_agent_service.should_not_receive(:configure_instance_service)
      @instance_service.should_not_receive(:verify!)
      @instance_service.should_not_receive(:fail!)
      @instance_service.configure_service
    end
  end

  describe 'verify_service' do
    before(:each) do
      @mock_agent_service.stub!(:verify_instance_service).and_return(true)
      @instance_service.stub!(:agent_service).and_return(@mock_agent_service)
      @instance_service.current_state = 'verifying'
    end

    it 'should delegate verify to the agent service' do
      @mock_agent_service.should_receive(:verify_instance_service).with(@instance_service).and_return(true)
      @instance_service.should_receive(:agent_service).and_return(@mock_agent_service)
      @instance_service.verify_service
    end

    it "should set the verified state if configuration verified" do
      @instance_service.should_receive(:run!)
      @instance_service.verify_service
    end

    it "should not change state if the configuration does not occur" do
      @mock_agent_service.should_receive(:verify_instance_service).with(@instance_service).and_return(false)
      @instance_service.should_not_receive(:run!)
      @instance_service.verify_service
    end

    it "should fail! if its stuck in :verifying too long" do
      @mock_agent_service.stub!(:verify_instance_service).and_return(false)
      @instance_service.should_receive(:stuck_in_state_for_too_long?).and_return(true)
      @instance_service.should_receive(:fail!)
      @instance_service.verify_service
    end
  end

  describe 'required_services_running?' do
    before(:each) do
      @required_service = Factory(:service)
      @instance_service.service.stub!(:required_services).and_return([@required_service])
      @required_instance_service = Factory(:instance_service, :service => @required_service)
      @environment = mock(Environment)
      @environment.stub_chain(:instance_services, :for_service).and_return([@required_instance_service])
      @instance_service.stub!(:environment).and_return(@environment)
    end

    it "should return true if there are no required services" do
      @instance_service.service.should_receive(:required_services).and_return([])
      @instance_service.required_services_running?.should == true
    end

    it "should return true if all of the instance_services for required services are running" do
      @required_instance_service.should_receive(:running?).and_return(true)
      @instance_service.required_services_running?.should == true
    end

    it "should return false if any of the instance_services for required services are !running" do
      @required_instance_service.should_receive(:running?).and_return(false)
      @instance_service.required_services_running?.should_not == true
    end
  end

  describe "deploy and undeploy" do
    before(:each) do
      @instance_service.stub!(:agent_service).and_return(@mock_agent_service)
      @mock_deployment = mock(Deployment)
    end

    it "deploy should delegate to the agent_service" do
      @mock_agent_service.should_receive(:deploy).with(@instance_service, @mock_deployment)
      @instance_service.deploy(@mock_deployment)
    end

    it "undeploy should delegate to the agent_service" do
      @mock_agent_service.should_receive(:undeploy).with(@instance_service, @mock_deployment)
      @instance_service.undeploy(@mock_deployment)
    end
  end

  context "metadata" do
    before(:each) do
      @metadata = { :x => "y" }
    end
    describe "metadata=" do
      it "should convert to json to save" do
        @instance_service.metadata = @metadata
        @instance_service.read_attribute(:metadata).should == @metadata.to_json
      end

      it "should properly handle nil" do
        @instance_service.metadata = nil
        @instance_service.read_attribute(:metadata).should == { }.to_json
      end
    end

    describe "metadata" do
      it "should convert from json on read" do
        @instance_service.stub!(:read_attribute).and_return(@metadata.to_json)
        @instance_service.metadata.should == @metadata
      end

      it "should properly handle nil" do
        @instance_service.stub!(:read_attribute).and_return(nil)
        @instance_service.metadata.should == { }
      end

      it "should properly handle malformed json" do
        @instance_service.stub!(:read_attribute).and_return("this is junk")
        @instance_service.metadata.should == { }
      end
    end
  end
end
