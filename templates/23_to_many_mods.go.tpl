{{- if or .Table.IsJoinTable .Table.IsView -}}
{{- else -}}
{{ $alias := .Aliases.Table .Table.Name -}}

{{range .Table.ToManyRelationships -}}
{{- $ltable := $.Aliases.Table .Table -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
{{- $col := $ltable.Column .Column}} 
{{- $fcol := $ftable.Column .ForeignColumn}} 
{{- $from := $relAlias.Local}} 
{{- $to :=  $ftable.DownSingular}}
{{- $type :=  printf "models.%sSlice" $ftable.UpSingular}}
{{- $usesPrimitives := usesPrimitives $.Tables .Table .Column .ForeignTable .ForeignColumn -}}
func {{$alias.UpSingular}}With{{$from}}(related {{$type}}) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		if o.R == nil {
			o.R = o.R.NewStruct()
		}

		o.R.{{$from}} = related

		for _, rel := range related {
			if rel.R == nil {
				rel.R = rel.R.NewStruct()
			}


			{{if .ToJoinTable -}}
				rel.R.{{$relAlias.Foreign}} = append(rel.R.{{$relAlias.Foreign}}, o)
			{{else}}
				{{if $usesPrimitives -}}
					rel.{{$fcol}} = o.{{$col}}
				{{else -}}
					queries.Assign(&rel.{{$fcol}}, o.{{$col}})
				{{end -}}

				{{if .Unique -}}
					rel.R.{{$relAlias.Foreign}} = o
				{{else -}}
					rel.R.{{$relAlias.Foreign}} = append(rel.R.{{$relAlias.Foreign}}, o)
				{{end -}}
			{{end -}}
		}

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

func {{$alias.UpSingular}}WithNew{{$from}}(f *Factory, number int, mods ...{{$ftable.UpSingular}}Mod) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
	  if f == nil {
		  f = defaultFactory
		}

		related, err := f.Create{{$ftable.UpPlural}}(number, mods...)
		if err != nil {
			return err
		}

		return {{$alias.UpSingular}}With{{$from}}(related).Apply(o)
	})
}

func {{$alias.UpSingular}}Add{{$from}}(related {{$type}}) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		if o.R == nil {
			o.R = o.R.NewStruct()
		}

		o.R.{{$from}} = append(o.R.{{$from}}, related...)

		for _, rel := range related {
			if rel.R == nil {
				rel.R = rel.R.NewStruct()
			}


			{{if .ToJoinTable -}}
				rel.R.{{$relAlias.Foreign}} = append(rel.R.{{$relAlias.Foreign}}, o)
			{{else}}
				{{if $usesPrimitives -}}
					rel.{{$fcol}} = o.{{$col}}
				{{else -}}
					queries.Assign(&rel.{{$fcol}}, o.{{$col}})
				{{end -}}

				{{if .Unique -}}
					rel.R.{{$relAlias.Foreign}} = o
				{{else -}}
					rel.R.{{$relAlias.Foreign}} = append(rel.R.{{$relAlias.Foreign}}, o)
				{{end -}}
			{{end -}}
		}

		return nil
	})
}

func {{$alias.UpSingular}}Add{{$from}}Func(f func() ({{$type}}, error)) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
		related, err := f()
		if err != nil {
			return err
		}

		return {{$alias.UpSingular}}Add{{$from}}(related).Apply(o)
	})
}

func {{$alias.UpSingular}}AddNew{{$from}}(f *Factory, number int, mods ...{{$ftable.UpSingular}}Mod) {{$alias.UpSingular}}Mod {
	return {{$alias.UpSingular}}ModFunc(func(o *models.{{$alias.UpSingular}}) error {
	  if f == nil {
		  f = defaultFactory
		}

		related, err := f.Create{{$ftable.UpPlural}}(number, mods...)
		if err != nil {
			return err
		}

		return {{$alias.UpSingular}}Add{{$from}}(related).Apply(o)
	})
}

{{end}}{{/* range tomany */}}
{{end}}
