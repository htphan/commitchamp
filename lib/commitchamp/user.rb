module Commitchamp
  class User < ActiveRecord::Base
    has_many :contributions
    has_many :repos, through: :contributions
  end
end