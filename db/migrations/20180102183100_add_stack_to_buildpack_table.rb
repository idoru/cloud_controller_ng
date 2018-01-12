## FIXME: Should this have been stack_id instead?
require 'yaml'
Sequel.migration do
  up do
    alter_table(:buildpacks) do
      add_column :stack, String, size: 255, null: true
      drop_index :name, unique: true
      add_index [:name, :stack], unique: true
    end

    ## FIXME: use default stack instead (could not work out how at this point)
    self['UPDATE buildpacks SET stack = ?', default_stack].update

    alter_table(:buildpacks) do
      set_column_not_null :stack
    end
  end

  down do
    alter_table(:buildpacks) do
      drop_index [:name, :stack], unique: true
      drop_column :stack
      add_index :name, unique: true
    end
  end

  def default_stack
    stacks_yml_path = ENV.fetch("STACKS_YML", nil)
    return YAML.load(File.read("/tmp/stacks.yml"))["default"] if stacks_yml_path && File.exist?(stacks_yml_path)
    'unknown'
  end
end
