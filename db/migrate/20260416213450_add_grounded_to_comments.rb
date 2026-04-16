class AddGroundedToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :grounded, :boolean, default: false, null: false
  end
end
