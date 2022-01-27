// This is to force strconv to be used. Without it, it causes an error because strconv is imported by ALL the drivers
var _ = strconv.IntSize


// These packages are needed in SOME models
// This is to prevent errors in those that do not need it
var _ = queries.Query{}

{{if and .Table.IsView (not .Table.ViewCapabilities.CanInsert) -}}
var (
	// These packages are used in factories for
	// tables and views that are insertable
	_ = fmt.Sprintln("")
	_ = context.Background()
	_ = boil.DebugMode
)
{{- end}}

{{ $alias := .Aliases.Table .Table.Name -}}

type {{$alias.UpSingular}}Mod interface {
	Apply(*models.{{$alias.UpSingular}}) error
}

type {{$alias.UpSingular}}ModFunc func(*models.{{$alias.UpSingular}}) error

func (f {{$alias.UpSingular}}ModFunc) Apply(n *models.{{$alias.UpSingular}}) error {
	return f(n)
}

type {{$alias.UpSingular}}Mods []{{$alias.UpSingular}}Mod

func (mods {{$alias.UpSingular}}Mods) Apply(n *models.{{$alias.UpSingular}}) error {
	for _, f := range mods {
		err := f.Apply(n)
		if err != nil {
			return err
		}
	}

	return nil
}

