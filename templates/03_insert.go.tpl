{{- if or (not .Table.IsView) (.Table.ViewCapabilities.CanInsert) -}}
{{ $alias := .Aliases.Table .Table.Name -}}

func Insert{{$alias.UpSingular}}(ctx context.Context, exec boil.ContextExecutor, o *models.{{$alias.UpSingular}}) error {
	return defaultFactory.Insert{{$alias.UpSingular}}(ctx, exec, o)
}

// Inserts the model in the given database
func (f Factory) Insert{{$alias.UpSingular}}(ctx context.Context, exec boil.ContextExecutor, o *models.{{$alias.UpSingular}}) error {
	var err error

	if o == nil {
		return fmt.Errorf("object to save must not be nil")
	}

	{{if not .Table.IsView -}}
	var key contextKey = "Inserted{{$alias.UpSingular}}"
	var val string = stringifyVal({{$.Table.PKey.Columns | stringMap (aliasCols $alias) | prefixStringSlice "o." | join ", "}})

	// Check if we have already inserted this model and skip if true
	if inContextKey(ctx, key, val) {
		return nil
	}

	if o.R == nil {
		o.R = o.R.NewStruct()
	}

	{{range $fk := .Table.FKeys -}}
	{{- if not ($.Table.GetColumn $fk.Column).Default -}}
	{{- $ltable := $.Aliases.Table $fk.Table -}}
	{{- $ftable := $.Aliases.Table $fk.ForeignTable -}}
	{{- $relAlias := $alias.Relationship $fk.Name -}}
	{{- $columnName := $ltable.Column $fk.Column -}} 
	{{- $from := $relAlias.Foreign -}} 
	{{- $usesPrimitives := usesPrimitives $.Tables .Table .Column .ForeignTable .ForeignColumn -}}
		if isZero(o.{{$columnName}}) {{if not $usesPrimitives}}|| queries.IsNil(o.{{$columnName}}){{end}} {
				related, err := f.CreateAndInsert{{$from}}(ctx, exec)
				if err != nil {
					return err
				}

				err = {{$alias.UpSingular}}With{{$from}}(related).Apply(o)
				if err != nil {
					return err
				}
		}
	{{end}}
	{{end}}
	{{- end}}{{/* End not .Table.IsView*/}}


	err = o.Insert(ctx, exec, boil.Infer())
	if err != nil {
		return err
	}

	{{if not .Table.IsView -}}
	// Save in context to ensure we don't enter an infinite loop when adding relationships
	ctx = addToContextKey(ctx, key, val)

	{{range $fk := .Table.ToOneRelationships -}}
	{{- $ltable := $.Aliases.Table .Table -}}
	{{- $ftable := $.Aliases.Table $fk.ForeignTable -}}
	{{- $col := $ltable.Column .Column}} 
	{{- $fcol := $ftable.Column .ForeignColumn}} 
	{{- $relAlias := $ftable.Relationship $fk.Name -}}
	{{- $columnName := $ftable.Column $fk.Column -}} 
	{{- $usesPrimitives := usesPrimitives $.Tables .Table .Column .ForeignTable .ForeignColumn -}}

	if o.R.{{$relAlias.Local}} != nil {
		// After inserting, the ID of our current model may have been updated
		// we should updated it in the relations before inserting
		{{if $usesPrimitives -}}
			o.R.{{$relAlias.Local}}.{{$fcol}} = o.{{$col}}
		{{else -}}
			queries.Assign(&o.R.{{$relAlias.Local}}.{{$fcol}}, o.{{$col}})
		{{end -}}


		{{- if .Unique -}}
			err = f.Insert{{$relAlias.Local}}(ctx, exec, o.R.{{$relAlias.Local}})
			if err != nil {
				return err
			}
		{{- else -}}
			for _, related := range o.R.{{$relAlias.Local}} {
				err = f.Insert{{$relAlias.Local}}(ctx, exec, related)
				if err != nil {
					return err
				}
			}
		{{end}}
	}

	{{end}}

	{{range $fk := .Table.ToManyRelationships -}}
	{{- $ltable := $.Aliases.Table $fk.Table -}}
	{{- $ftable := $.Aliases.Table $fk.ForeignTable -}}
	{{- $col := $ltable.Column .Column}} 
	{{- $fcol := $ftable.Column .ForeignColumn}} 
	{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
	{{- $columnName := $ftable.Column $fk.Column -}} 
	{{- $from := $relAlias.Foreign -}} 
	{{- $usesPrimitives := usesPrimitives $.Tables .Table .Column .ForeignTable .ForeignColumn -}}

	if len(o.R.{{$relAlias.Local}}) > 0 {
		{{if .ToJoinTable -}}
			err = f.Insert{{$relAlias.Local}}(ctx, exec, o.R.{{$relAlias.Local}})
			if err != nil {
				return err
			}
			
			// Set values in the join table
			err = o.Set{{$relAlias.Local}}(ctx, exec, false, o.R.{{$relAlias.Local}}...)
			if err != nil {
				return err
			}
		{{else -}}
			for _, related := range o.R.{{$relAlias.Local}} {
			  // After inserting, the ID of our current model may have been updated
				// we should updated it in the relations before inserting
				{{if $usesPrimitives -}}
					related.{{$fcol}} = o.{{$col}}
				{{else -}}
					queries.Assign(&related.{{$fcol}}, o.{{$col}})
				{{end -}}

			  err = f.Insert{{$ftable.UpSingular}}(ctx, exec, related)
				if err != nil {
					return err
				}
			}
		{{- end -}}
		}

	{{end}}
	{{- end}}{{/* End not .Table.IsView*/}}

	return nil
}



func Insert{{$alias.UpPlural}}(ctx context.Context, exec boil.ContextExecutor, objs models.{{$alias.UpSingular}}Slice) error {
	return defaultFactory.Insert{{$alias.UpPlural}}(ctx, exec, objs)
}

func (f Factory) Insert{{$alias.UpPlural}}(ctx context.Context, exec boil.ContextExecutor, objs models.{{$alias.UpSingular}}Slice) error {
  for _, o := range objs {
		err := f.Insert{{$alias.UpSingular}}(ctx, exec, o)
		if err != nil {
			return err
		}
	}

	return nil
}

{{end}}
