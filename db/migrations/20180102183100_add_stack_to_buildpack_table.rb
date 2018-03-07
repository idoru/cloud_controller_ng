require 'yaml'

def default_stack
  stacks_yml_path = ENV.fetch('STACKS_YML', nil)
  YAML.safe_load(File.read(stacks_yml_path))['default'] if stacks_yml_path && File.exist?(stacks_yml_path)
end

Sequel.migration do
  up do
    alter_table(:buildpacks) do
      add_column :stack, String, size: 255, default: default_stack || 'unknown', null: false
      drop_index :name, unique: true
      add_index [:name, :stack], unique: true, name: :unique_name_and_stack
    end
  end

  down do
    alter_table(:buildpacks) do
      drop_index [:name, :stack], unique: true, name: :unique_name_and_stack
      drop_column :stack
      add_index :name, unique: true, name: :buildpacks_name_index
    end
  end
end
