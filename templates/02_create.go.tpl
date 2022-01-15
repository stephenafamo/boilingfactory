{{ $alias := .Aliases.Table .Table.Name -}}

func Create{{$alias.UpSingular}}(mods ...{{$alias.UpSingular}}Mod) (*models.{{$alias.UpSingular}}, error) {
	return defaultFactory.Create{{$alias.UpSingular}}(mods...)
}

func (f Factory) Create{{$alias.UpSingular}}(mods ...{{$alias.UpSingular}}Mod) (*models.{{$alias.UpSingular}}, error) {
	o := &models.{{$alias.UpSingular}}{}

	baseMod := f.base{{$alias.UpSingular}}Mod
	if baseMod != nil {
		err := baseMod.Apply(o)
		if err != nil {
			return nil, err
		}
	}

	err := {{$alias.UpSingular}}Mods(mods).Apply(o)

	return o, err
}


func Create{{$alias.UpPlural}}(number int, mods ...{{$alias.UpSingular}}Mod) (models.{{$alias.UpSingular}}Slice, error) {
	return defaultFactory.Create{{$alias.UpPlural}}(number, mods...)
}

func (f Factory) Create{{$alias.UpPlural}}(number int, mods ...{{$alias.UpSingular}}Mod) (models.{{$alias.UpSingular}}Slice, error) {
	var err error
  var created = make(models.{{$alias.UpSingular}}Slice, number)

  for i := 0; i < number; i++ {
		created[i], err = f.Create{{$alias.UpSingular}}(mods...)
		if err != nil {
			return nil, err
		}
	}

	return created, nil
}

