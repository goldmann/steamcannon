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

describe InstancesController do
  before(:each) do
    login
    @instances = [Factory(:instance)]
    @instances.stub!(:to_json).and_return("{}")
    @current_user.stub!(:environments).and_return(Environment)
    mock_environment.stub!(:instances).and_return(@instances)
  end

  def mock_environment(stubs={})
    @mock_environment ||= mock_model(Environment, stubs)
  end

  describe "GET index" do
    before(:each) do
      Environment.stub!(:find).with("13").and_return( mock_environment )
      get :index, :environment_id => "13"
    end

    it "should assign the requested environment as @environment" do
      assigns[:environment].should equal(mock_environment)
    end

    it "should assign the requested instances as @instances" do
      get :index, :environment_id => "13"
      assigns[:instances].should equal(@instances)
    end

    it "should scope requests to the current_user" do
      @current_user.should_receive(:environments)
      get :index, :environment_id => "13"
    end

    it "should scope requests to the current_user's environments" do
      mock_environment.should_receive(:instances)
      get :index, :environment_id => "13"
    end

  end

  describe "GET show" do
    before(:each) do
      Environment.stub!(:find).with("13").and_return( mock_environment )
      mock_environment.instances.stub(:find).with("1").and_return(@instances.first)
    end

    it "should assign the requested environment as @environment" do
      get :show, :id => "1", :environment_id => "13"
      assigns[:environment].should equal(mock_environment)
    end

    it "should assign the requested instance as @instance" do
      mock_environment.instances.should_receive(:find).with("1").and_return(@instances.first)
      get :show, :id => "1", :environment_id => "13"
      assigns[:instance].should equal(@instances.first)
    end

    it "should scope requests to the current_user" do
      @current_user.should_receive(:environments)
      get :show, :id => "1", :environment_id => "13"
    end

    it "should scope requests to the current_user's environments" do
      mock_environment.should_receive(:instances)
      get :show, :id => "1", :environment_id => "13"
    end

  end

  describe "POST stop" do
    before(:each) do
      Environment.stub!(:find).with("13").and_return( mock_environment )
      @instances.first.stub!(:stop!)
      mock_environment.instances.stub(:find).with("1").and_return(@instances.first)
      mock_environment.stub!(:instances).and_return(@instances)
    end

    it "should assign the requested environment as @environment" do
      mock_environment.instances.stub!(:find).with("1").and_return(@instances.first)
      post :stop, :id => "1", :environment_id => "13"
      assigns[:environment].should equal(mock_environment)
    end

    it "should assign the requested instance as @instance" do
      mock_environment.instances.should_receive(:find).with("1").and_return(@instances.first)
      post :stop, :id => "1", :environment_id => "13"
      assigns[:instance].should equal(@instances.first)
    end

    it "should stop the instance" do
      mock_environment.instances.stub!(:find).with("1").and_return(@instances.first)
      @instances.first.should_receive(:stop!)
      post :stop, :id => "1", :environment_id => "13"
    end
  end

  describe "POST status" do
    before(:each) do
      Environment.stub!(:find).with("13").and_return( mock_environment )
      mock_environment.instances.stub(:find).with("1").and_return(@instances.first)
      mock_environment.stub!(:instances).and_return(@instances)
    end

    it "should assign the requested environment as @environment" do
      mock_environment.instances.stub!(:find).with("1").and_return(@instances.first)
      post :status, :id => "1", :environment_id => "13"
      assigns[:environment].should equal(mock_environment)
    end

    it "should assign the requested instance as @instance" do
      mock_environment.instances.should_receive(:find).with("1").and_return(@instances.first)
      post :status, :id => "1", :environment_id => "13"
      assigns[:instance].should equal(@instances.first)
    end

    it "should render the instances row partial" do
      controller.should_receive(:render_to_string).with(hash_including(:partial => 'instances/row'))
      post :status, :id => "1", :environment_id => "13"
    end
  end

  describe "POST clone" do
    describe "with valid params" do
      it "should clone the requested instance"
      it "should only allow instances that are running to be cloned"
      it "should assign a newly created instance as @instance"
      it "should redirect to the environment"
    end

    describe "with invalid params" do
      it "should not assign a newly created instance as @instance"
      it "should redirect to the environment"
    end
  end

end
