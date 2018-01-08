Sequel.migration do
  up do
    alter_table(:buildpacks) do
      drop_index :name, unique: true
      index [:name, :stack], unique: true
    end
  end

  down do
    alter_table(:buildpacks) do
      drop_index [:name, :stack], unique: true
      index :name, unique: true
    end
  end
end
