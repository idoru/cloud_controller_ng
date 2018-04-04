require 'yaml'

def stacks_yml
  stacks_yml_path = ENV.fetch("STACKS_YML", nil)
  YAML.load(File.read(stacks_yml_path)) if stacks_yml_path && File.exist?(stacks_yml_path)
end

def default_stack
  stacks_yml["default"] if stacks_yml
end

def latest_windows_stack
  return unless stacks_yml
  stack_names = stacks_yml["stacks"].map { |stack| stack["name"] }
  if stack_names.include?("windows2016")
    return "windows2016"
  end
  if stack_names.include?("windows2012R2")
    return "windows2012R2"
  end
  return nil
end

Sequel.migration do
  up do
    alter_table(:buildpacks) do
      add_column :stack, String, size: 255, null: true
      drop_index :name, unique: true
      add_index [:name, :stack], unique: true, name: :unique_name_and_stack
    end
    self[:buildpacks].where(Sequel.negate(name: "hwc_buildpack")).update(stack: default_stack) if default_stack
    self[:buildpacks].where(name: "hwc_buildpack").update(stack: latest_windows_stack) if latest_windows_stack
  end

  down do
    alter_table(:buildpacks) do
      drop_index [:name, :stack], unique: true, name: :unique_name_and_stack
      drop_column :stack
      add_index :name, unique: true, name: :buildpacks_name_index
    end
  end
end
