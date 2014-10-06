#Inside a ruby block all the methods of the class TemplateManager are accessible
#because a new envir is created as in the body of such a method called new_envir

#The main difference between this kind of helpers and a simple file containing definition of functions
#is that these functions are executed in the Object module as a normal ruby function does. 
   
module Dyndoc

  module MRuby

    module Helpers

      # Helpers are functions (in fact methods) used inside a ruby block!
      # Put here only system helpers!
      # The user is pleased to create helpers in the dyndoc/helpers directory
      # and require them by the [#helpers] tag. The following is just an example!

      def hello!(who="everybody") 
        puts "Hello "+who+"!"
      end

    end
  
    class TemplateManager

    include Helpers 

    end

  end

end
