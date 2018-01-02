Sequel.migration do
  up do
    alter_table(:buildpacks) do
      add_column :stack, String, size: 255, null: true
      drop_index name: :buildpacks_name_index
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
