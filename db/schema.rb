# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_06_112313) do
  create_table "events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "held_on"
    t.bigint "place_id", null: false
    t.string "public_uid", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["place_id"], name: "index_events_on_place_id"
    t.index ["public_uid"], name: "index_events_on_public_uid", unique: true
  end

  create_table "places", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "name"
    t.string "public_uid", null: false
    t.datetime "updated_at", null: false
    t.index ["public_uid"], name: "index_places_on_public_uid", unique: true
  end

  create_table "requests", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "comment"
    t.bigint "correctable_id", null: false
    t.string "correctable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["correctable_type", "correctable_id"], name: "index_requests_on_correctable"
  end

  add_foreign_key "events", "places"
end
