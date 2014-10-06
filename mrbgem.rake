MRuby::Gem::Specification.new('mruby-dyndoc') do |spec|
  spec.license = 'MIT'
  spec.author  = 'R Cqls'

  spec.rbfiles = ['dyndoc.rb',
    'dyndoc/strscan_dyndoc.rb',
    'dyndoc/scanner.rb',
    'dyndoc/tmpl/manager.rb',
		'dyndoc/tmpl/parse_do.rb',
		'dyndoc/tmpl/eval.rb',
		'dyndoc/tmpl/extension.rb',
		'dyndoc/tmpl/oop.rb',
		'dyndoc/tmpl/rbenvir.rb',
		'dyndoc/helpers/core.rb',
		'dyndoc/helpers/parser.rb',
		'dyndoc/helpers/utils.rb',
		'dyndoc/filter/filter_mngr.rb',
		'dyndoc/filter/server.rb',
		'dyndoc/envir.rb'].map{|e| File.join("#{dir}/mrblib",e)}


  spec.mruby.cc.defines << 'ENABLE_DEBUG'
  spec.cc.defines << 'ENABLE_DEBUG'

  # Add GEM dependency mruby-parser.
  # The version must be between 1.0.0 and 1.5.2 .
  #spec.add_dependency('mruby-parser', '>= 1.0.0', '<= 1.5.2')

  # Use any version of mruby-uv from github.
  #spec.add_dependency('mruby-uv', '>= 0.0.0', :github => 'mattn/mruby-uv')

  # Use latest mruby-onig-regexp from github. (version requirements can be ignored)
  #spec.add_dependency('mruby-onig-regexp', :github => 'mattn/mruby-onig-regexp')

end