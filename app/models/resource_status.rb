class ResourceStatus < ActiveRecord::Base
  belongs_to :report
  has_many :events, :class_name => "ResourceEvent"

  serialize :tags, Array
end
