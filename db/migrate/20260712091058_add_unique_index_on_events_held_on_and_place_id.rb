class AddUniqueIndexOnEventsHeldOnAndPlaceId < ActiveRecord::Migration[8.1]
  def up
    duplicates = select_all(<<~SQL.squish)
      SELECT held_on, place_id, COUNT(*) AS duplicate_count
      FROM events
      GROUP BY held_on, place_id
      HAVING COUNT(*) > 1
    SQL

    if duplicates.any?
      details = duplicates.map { |row|
        "held_on=#{row["held_on"]} place_id=#{row["place_id"]} count=#{row["duplicate_count"]}"
      }.join(", ")
      raise "Cannot add unique index on events(held_on, place_id); duplicates found: #{details}"
    end

    add_index :events, [ :held_on, :place_id ], unique: true, name: "index_events_on_held_on_and_place_id"
  end

  def down
    remove_index :events, name: "index_events_on_held_on_and_place_id"
  end
end
