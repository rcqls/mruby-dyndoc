# require 'dyndoc/strscan_dyndoc.rb'
# require 'dyndoc/scanner.rb'
# require 'dyndoc/tmpl/manager.rb'
# require 'dyndoc/tmpl/parse_do.rb'
# require 'dyndoc/tmpl/eval.rb'
# require 'dyndoc/tmpl/extension.rb'
# require 'dyndoc/tmpl/oop.rb'
# require 'dyndoc/tmpl/rbenvir.rb'
# require 'dyndoc/helpers/core.rb'
# require 'dyndoc/helpers/parser.rb'
# require 'dyndoc/helpers/utils.rb'
# require 'dyndoc/filter/filter_mngr.rb'
# require 'dyndoc/filter/server.rb'
# require 'dyndoc/envir.rb'


module Dyndoc
  def Dyndoc.stdout
          old_stdout=$stdout;$stdout=STDOUT
          $stdout.flush
          yield
          $stdout=old_stdout
          $stdout.flush
  end

  def Dyndoc.warn(*txt) # 1 component => puts, more components => puts + p + p + ....
          Dyndoc.stdout  do
                  if txt.length==1
                          puts txt[0]
                  else
                          puts txt[0]
                          txt[1..-1].each do |e| p e end
                  end
          end
  end
end