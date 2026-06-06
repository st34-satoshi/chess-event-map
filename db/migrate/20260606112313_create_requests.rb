class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :requests do |t|
      t.references :correctable, polymorphic: true, null: false
      t.text :comment

      t.timestamps
    end
  end
end
