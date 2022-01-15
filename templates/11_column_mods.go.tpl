{{ $alias := .Aliases.Table .Table.Name -}}

{{range $column := .Table.Columns}}
{{$colAlias := $alias.Column $column.Name -}}

func {{$alias.UpSingular}}{{$colAlias}}(val {{$column.Type}}) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		o.{{$colAlias}} = val
		return nil
	})
}

func {{$alias.UpSingular}}{{$colAlias}}Func(f func() ({{$column.Type}}, error)) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		var err error
		o.{{$colAlias}}, err = f()
		return err
	})
}

{{end}}
