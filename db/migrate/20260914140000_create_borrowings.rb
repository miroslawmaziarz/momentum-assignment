class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :book, null: false, foreign_key: { on_delete: :cascade }
      t.references :reader, null: false, foreign_key: true

      t.datetime :borrowed_at, null: false
      t.datetime :due_at, null: false
      t.datetime :returned_at

      t.timestamps
    end

    add_index :borrowings, :book_id, unique: true, where: "returned_at IS NULL",
                                     name: "index_borrowings_on_open_book"
  end
end
