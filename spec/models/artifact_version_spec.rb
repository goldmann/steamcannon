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

describe ArtifactVersion do
  before(:each) do
    @valid_attributes = {
      :artifact_id => 1,
      :version_number => 1,
      :archive_file_name => "value for archive_file_name",
      :archive_content_type => "value for archive_content_type",
      :archive_file_size => "value for archive_file_size",
      :archive_updated_at => "value for archive_updated_at"
    }
  end

  it "should create a new instance given valid attributes" do
    artifact_version = ArtifactVersion.new(@valid_attributes)
    artifact_version.stub!(:assign_version_number)
    artifact_version.save!
  end

  it "should belong to an artifact" do
    ArtifactVersion.new.should respond_to(:artifact)
  end

  it "should assign a version number before creating" do
    artifact_version = ArtifactVersion.new(@valid_attributes)
    artifact_version.should_receive(:assign_version_number)
    artifact_version.save!
  end

  it "should assign 1 as the first version number" do
    artifact = mock_model(Artifact, :latest_version_number => nil)
    artifact_version = ArtifactVersion.new(@valid_attributes)
    artifact_version.stub!(:artifact).and_return(artifact)
    artifact_version.save!
    artifact_version.version_number.should be(1)
  end

  it "should return artifact's name and version as to_s" do
    artifact = Artifact.new(:name => "test artifact")
    artifact_version = ArtifactVersion.new
    artifact_version.artifact = artifact
    artifact_version.version_number = 2
    artifact_version.to_s.should eql("test artifact version 2")
  end
end