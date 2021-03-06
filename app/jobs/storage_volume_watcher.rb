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


class StorageVolumeWatcher

  def run
    destroy_volumes_pending_delete
    check_for_volume_existence
  end

  def destroy_volumes_pending_delete
    StorageVolume.pending_delete.each(&:real_destroy)
  end

  def check_for_volume_existence
    StorageVolume.should_exist.each do |sv|
      sv.not_found! unless sv.cloud_volume_exists?
    end
  end
end

