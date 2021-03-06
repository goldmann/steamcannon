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


class Artifact < ActiveRecord::Base
  belongs_to :user
  belongs_to :service
  belongs_to :cloud_profile
  
  has_many :artifact_versions, :dependent => :destroy
  has_many :deployments, :through => :artifact_versions
  
  attr_protected :user
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :user_id
  validates_presence_of :cloud_profile

  accepts_nested_attributes_for :artifact_versions

  def latest_version
    artifact_versions.first(:order => 'version_number desc')
  end

  def latest_version_number
    latest_version ? latest_version.version_number : nil
  end

  def service_name
    service.try(:full_name) || 'None'
  end

  def deployment_for_instance_service(instance_service)
    deployments.deployed.detect { |d| d.instance_services.exists?(instance_service.id) }
  end

  def is_deployed?
    artifact_versions.any?(&:is_deployed?)
  end
end

