class PlatformVersion < ActiveRecord::Base
  belongs_to :platform
  has_many :images, :through => :platform_version_images
end
