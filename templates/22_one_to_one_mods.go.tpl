{{- if or .Table.IsJoinTable .Table.IsView -}}
{{- else -}}
{{ $alias := .Aliases.Table .Table.Name -}}

{{range .Table.ToOneRelationships -}}
{{- $ltable := $.Aliases.Table .Table -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $ftable.Relationship .Name -}}
{{- $col := $ltable.Column .Column}} 
{{- $fcol := $ftable.Column .ForeignColumn}} 
{{- $from := $relAlias.Local}} 
{{- $to :=  $ftable.DownSingular}}
{{- $type :=  printf "*models.%s" $ftable.UpSingular}}
{{- $usesPrimitives := usesPrimitives $.Tables .Table .Column .ForeignTable .ForeignColumn -}}
func {{$alias.UpSingular}}With{{$from}}(related {{$type}}) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		if o.R == nil {
			o.R = o.R.NewStruct()
		}

		o.R.{{$from}} = related

		if related.R == nil {
			related.R = related.R.NewStruct()
		}

		{{if $usesPrimitives -}}
			related.{{$fcol}} = o.{{$col}}
		{{else -}}
			queries.Assign(&related.{{$fcol}}, o.{{$col}})
		{{end -}}

		{{if .Unique -}}
			related.R.{{$relAlias.Foreign}} = o
		{{else -}}
			related.R.{{$relAlias.Foreign}} = append(related.R.{{$relAlias.Foreign}}, o)
		{{end -}}

		return nil
	})
}

func {{$alias.UpSingular}}With{{$from}}Func(f func() ({{$type}}, error)) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		related, err := f()
		if err != nil {
			return err
		}

		return {{$alias.UpSingular}}With{{$from}}(related).Apply(o)
	})
}

func {{$alias.UpSingular}}WithNew{{$from}}(f *Factory, mods ...{{$ftable.UpSingular}}Mod) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
	  if f == nil {
		  f = defaultFactory
		}

		related, err := f.Create{{$ftable.UpSingular}}(mods...)
		if err != nil {
			return err
		}

		return {{$alias.UpSingular}}With{{$from}}(related).Apply(o)
	})
}


{{end}}
{{end}}
