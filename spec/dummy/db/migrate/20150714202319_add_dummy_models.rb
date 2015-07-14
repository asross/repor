class AddDummyModels < ActiveRecord::Migration
  def change
    create_table :posts, force: true do |t|
      t.timestamps
      t.string :title
      t.integer :likes, null: false, default: 0
    end

    create_table :comments, force: true do |t|
      t.timestamps
      t.string :author
      t.integer :likes, null: false, default: 0
      t.integer :post_id, null: false
    end
  end
end
