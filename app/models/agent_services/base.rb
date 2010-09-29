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

module AgentServices
  class Base
    
    class << self
      def instance_for_service(service, environment)
        klass = self
        begin
          require "agent_services/#{service.name}"
          klass = "AgentServices::#{service.name.camelize}".constantize
        rescue MissingSourceFile => ex
          Rails.logger.debug "AgentServices::Base.instance_for_service: require failed for agent_services/#{service.name}"
        rescue NameError => ex
          Rails.logger.debug "AgentServices::Base.instance_for_service: constantize failed: #{ex.message}"
        end
        Rails.logger.debug "AgentServices::Base.instance_for_service: using #{klass.name} for #{service.name}"
        klass.new(service, environment)
      end
    end
    
    attr_reader :service, :environment

    def initialize(service, environment)
      @service = service
      @environment = environment
    end

    def deploy(deployments)
      instances = instances_for_deploy

      return false if instances.empty?
      
      deployments.each do |deployment|
        remote_artifact_id = nil
        success = instances.inject(true) do |accumulated_success, instance|
          result = deploy_to_instance(instance, deployment)
          remote_artifact_id ||= result
          accumulated_success && result
        end

        deployment.agent_artifact_identifier = remote_artifact_id
        
        success ? deployment.mark_as_deployed! : deployment.fail!
        
        success
      end
    end

    def deploy_to_instance(instance, deployment)
      response = false

      #see if the deployment has already been deployed, and bail if so
      return response if instance.deployments.exists?(deployment)

      #see if another version of this artifact has been deployed, and
      #udeploy that first if so
      #FIXME: this currently ignores the result of the undeploy operation
      other_deployment = deployment.artifact.deployment_for_instance(instance)
      undeploy(other_deployment) if other_deployment
      
      begin
        result_hash = instance.agent_client(service).deploy_artifact(deployment.artifact_version)
        if result_hash.respond_to?(:[]) and result_hash['artifact_id']
          response = result_hash['artifact_id']
          instance.deployments << deployment
        end
      rescue AgentClient::RequestFailedError => ex
        #TODO: store the failure reason?
        Rails.logger.info "deploying artifact failed: #{ex}"
        Rails.logger.info ex.backtrace.join("\n")
      end

      response
    end

    def undeploy(deployment)
      success = deployment.instances.inject(true) do |accumulated_success, instance|
        accumulated_success && undeploy_from_instance(instance, deployment)
      end

      deployment.mark_as_undeployed! if success
      
      success
    end

    def undeploy_from_instance(instance, deployment)
      instance.agent_client(service).undeploy_artifact(deployment.agent_artifact_identifier)
      instance.instance_deployments.find_by_deployment_id(deployment.id).destroy
      true
    rescue AgentClient::RequestFailedError => ex
      #TODO: store the failure reason?
      Rails.logger.info "undeploying artifact failed: #{ex}"
      Rails.logger.info ex.backtrace.join("\n")
      false
    end

    def instances_for_deploy
      service.instances.running.in_environment(environment)
    end

    def verify_instance(instance)
      result = instance.agent_client(service).status
      result['state'] and result['state'] == 'started'
    end

    def configure_instance(instance)
      #noop, should be overridden in service specific child
      Rails.logger.debug "AgentServices::Base#configure_instance called - should #{service.name} have its own configure strategy?"
      true
    end
  end
end
