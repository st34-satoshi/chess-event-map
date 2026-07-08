namespace :db do
  desc "Create solid_queue, solid_cache, and solid_cable tables if missing"
  task prepare_solid: :environment do
    {
      queue: "solid_queue_jobs",
      cache: "solid_cache_entries",
      cable: "solid_cable_messages"
    }.each do |name, marker_table|
      config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name.to_s)
      next unless config

      ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(config) do |connection|
        next if connection.table_exists?(marker_table)

        schema_file = Rails.root.join("db/#{name}_schema.rb")
        puts "Loading #{schema_file}..."
        ActiveRecord::Tasks::DatabaseTasks.load_schema(config, :ruby, schema_file)
      end
    end
  end
end
