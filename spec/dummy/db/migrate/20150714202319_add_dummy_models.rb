class AddDummyModels < ActiveRecord::Migration[5.1]
  def change
    create_table :posts, force: true do |t|
      t.timestamps
      t.string :title
      t.integer :author_id
      t.integer :status, null: false, default: 0
      t.integer :likes, null: false, default: 0
      t.integer :category
      t.timestamp :published_at
    end

    create_table :comments, force: true do |t|
      t.timestamps
      t.integer :post_id
      t.integer :author_id
      t.integer :likes, null: false, default: 0
    end

    create_table :authors, force: true do |t|
      t.timestamps
      t.string :name
    end
  end
end
