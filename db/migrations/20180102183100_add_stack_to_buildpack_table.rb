## FIXME: Should this have been stack_id instead?
Sequel.migration do
  up do
    alter_table(:buildpacks) do
      add_column :stack, String, size: 255, null: true
    end

    ## FIXME: use default stack instead (could not work out how at this point)
    self['UPDATE buildpacks SET stack = ?', 'cflinuxfs2'].update

    alter_table(:buildpacks) do
      set_column_not_null :stack
    end
  end

  down do
    alter_table(:buildpacks) do
      drop_column :stack
    end
  end
end
