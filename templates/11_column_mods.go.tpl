{{ $alias := .Aliases.Table .Table.Name -}}

{{range $column := .Table.Columns}}
{{$colAlias := $alias.Column $column.Name -}}
{{$isEnum := and $.AddEnumTypes (ne (parseEnumName $column.DBType) "")}}

func {{$alias.UpSingular}}{{$colAlias}}(val {{if $isEnum}}models.{{end}}{{$column.Type}}) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		o.{{$colAlias}} = val
		return nil
	})
}

func {{$alias.UpSingular}}{{$colAlias}}Func(f func() ({{if $isEnum}}models.{{end}}{{$column.Type}}, error)) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		var err error
		o.{{$colAlias}}, err = f()
		return err
	})
}

{{end}}
