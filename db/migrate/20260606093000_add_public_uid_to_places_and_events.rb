class AddPublicUidToPlacesAndEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :places, :public_uid, :string
    add_column :events, :public_uid, :string

    backfill_public_uid(:places)
    backfill_public_uid(:events)

    change_column_null :places, :public_uid, false
    change_column_null :events, :public_uid, false
    add_index :places, :public_uid, unique: true
    add_index :events, :public_uid, unique: true
  end

  def down
    remove_index :places, :public_uid
    remove_index :events, :public_uid
    remove_column :places, :public_uid
    remove_column :events, :public_uid
  end

  private

  def backfill_public_uid(table)
    select_all("SELECT id FROM #{table}").each do |row|
      update <<-SQL.squish
        UPDATE #{table}
        SET public_uid = #{quote(generate_public_uid(table))}
        WHERE id = #{row["id"]}
      SQL
    end
  end

  def generate_public_uid(table)
    loop do
      uid = SecureRandom.alphanumeric(12)
      return uid unless select_value("SELECT 1 FROM #{table} WHERE public_uid = #{quote(uid)}")
    end
  end
end
