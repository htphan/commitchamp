module Commitchamp
  class Contribution < ActiveRecord::Base
    belongs_to :repo
    belongs_to :user
  end
end