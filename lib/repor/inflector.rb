ActiveSupport::Inflector.inflections(:_gem_repor) do |inflect|
  sys_inflect = ActiveSupport::Inflector.inflections
  %i(acronyms humans uncountables singulars plurals acronyms_camelize_regex acronyms_underscore_regex).each do |var|
    inflect.instance_variable_set("@#{var}", sys_inflect.send(var).dup)
  end

  inflect.uncountable 'delta'
end
