class CreateContributions < ActiveRecord::Migration
  def change
    create_table :contributions do |t|
      t.integer   :user_id
      t.integer   :repo_id
      t.integer   :additions
      t.integer   :deletions
      t.integer   :commits      # commits
    end
  end
end