type Factory struct {
    {{range $table := .Tables}}{{if not $table.IsJoinTable -}}
    {{ $alias := $.Aliases.Table $table.Name -}}
		base{{$alias.UpSingular}}Mod {{$alias.UpSingular}}Mod
    {{end}}{{- end}}
}

var defaultFactory = new(Factory)

{{range $table := .Tables}}{{if not $table.IsJoinTable -}}
{{ $alias := $.Aliases.Table $table.Name -}}
func SetBase{{$alias.UpSingular}}Mod(mod {{$alias.UpSingular}}Mod) {
    defaultFactory.SetBase{{$alias.UpSingular}}Mod(mod)
}

{{ $alias := $.Aliases.Table $table.Name -}}
func (f *Factory) SetBase{{$alias.UpSingular}}Mod(mod {{$alias.UpSingular}}Mod) {
    f.base{{$alias.UpSingular}}Mod = mod
}

{{end}}{{- end}}

func isZero(value interface{}) bool {
	val := reflect.Indirect(reflect.ValueOf(value))
	typ := val.Type()

	zero := reflect.Zero(typ)
	return reflect.DeepEqual(zero.Interface(), val.Interface())
}


type contextKey string

func inContextKey(ctx context.Context, key contextKey, val string) bool {
  vals, _ := ctx.Value(key).(map[string]struct{})
  if vals == nil {
      return false
  }

  _, ok := vals[val]
  return ok
}

func addToContextKey(ctx context.Context, key contextKey, val string) context.Context {
  vals, _ := ctx.Value(key).(map[string]struct{})
  if vals == nil {
      vals = map[string]struct{}{
          val: {},
      }
  } else {
      vals[val] = struct{}{}
  }

  return context.WithValue(ctx, key, vals)
}

func stringifyVal(val ...interface{}) string {
  strVal := ""

  for _, v := range val {
      strVal += fmt.Sprintf("%v", v)
  }

  return strVal
}
