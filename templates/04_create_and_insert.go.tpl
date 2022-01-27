{{- if or (not .Table.IsView) (.Table.ViewCapabilities.CanInsert) -}}
{{ $alias := .Aliases.Table .Table.Name -}}

func CreateAndInsert{{$alias.UpSingular}}(ctx context.Context, exec boil.ContextExecutor, mods ...{{$alias.UpSingular}}Mod) (*models.{{$alias.UpSingular}}, error) {
	return defaultFactory.CreateAndInsert{{$alias.UpSingular}}(ctx, exec, mods...)
}

func (f Factory) CreateAndInsert{{$alias.UpSingular}}(ctx context.Context, exec boil.ContextExecutor, mods ...{{$alias.UpSingular}}Mod) (*models.{{$alias.UpSingular}}, error) {
	o, err := f.Create{{$alias.UpSingular}}(mods...)
	if err != nil {
		return nil, err
	}

	err = f.Insert{{$alias.UpSingular}}(ctx, exec, o)

	return o, err
}


func CreateAndInsert{{$alias.UpPlural}}(ctx context.Context, exec boil.ContextExecutor, number int, mods ...{{$alias.UpSingular}}Mod) (models.{{$alias.UpSingular}}Slice, error) {
	return defaultFactory.CreateAndInsert{{$alias.UpPlural}}(ctx, exec, number, mods...)
}

func (f Factory) CreateAndInsert{{$alias.UpPlural}}(ctx context.Context, exec boil.ContextExecutor, number int, mods ...{{$alias.UpSingular}}Mod) (models.{{$alias.UpSingular}}Slice, error) {
	var err error
  var inserted = make(models.{{$alias.UpSingular}}Slice, number)

  for i := 0; i < number; i++ {
		inserted[i], err = f.CreateAndInsert{{$alias.UpSingular}}(ctx, exec, mods...)
		if err != nil {
			return nil, err
		}
	}

	return inserted, nil
}

{{end}}
