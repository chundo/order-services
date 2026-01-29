class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.integer :customer_id, null: false
      t.string :product_name, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :orders, :customer_id
    add_index :orders, :status
  end
end
