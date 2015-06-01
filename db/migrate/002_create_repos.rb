class CreateRepos < ActiveRecord::Migration
  def change
    create_table :repos do |t|
      t.string  :name
      t.string  :organization   # owner
      t.string  :full_name  
    end
  end
end
