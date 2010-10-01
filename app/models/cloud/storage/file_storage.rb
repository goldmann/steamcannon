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

module Cloud
  module Storage

    # Adapted from lib/paperclip/storage/filesystem.rb
    class FileStorage

      def initialize(ignored_username, ignored_password)
        # No credentials needed for file-based storage
      end

      def exists?(path)
        File.exist?(path)
      end

      def to_file(path)
        (File.new(path, 'rb')) if exists?(path)
      end

      def write(path, file, attachment)
        file.close
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.cp(file.path, path)
        FileUtils.rm(file.path)
        FileUtils.chmod(0644, path)
      end

      def delete(path)
        FileUtils.rm(path) if exists?(path)
      rescue Errno::ENOENT => e
        # ignore file-not-found, let everything else pass
      end

      def public_url
        nil
      end

    end
  end
end
