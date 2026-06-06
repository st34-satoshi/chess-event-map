class AddPlaceToEvents < ActiveRecord::Migration[8.1]
  def up
    add_reference :events, :place, foreign_key: true

    execute <<~SQL.squish
      UPDATE events
      SET place_id = (SELECT id FROM places ORDER BY id LIMIT 1)
      WHERE place_id IS NULL
    SQL

    change_column_null :events, :place_id, false
  end

  def down
    remove_reference :events, :place, foreign_key: true
  end
end
