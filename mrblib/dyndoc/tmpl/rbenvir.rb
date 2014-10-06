module Dyndoc
  module MRuby
  
    class TemplateManager

      def binding
        # closure
        #Kernel
        :nil
      end

      def rbenvir_init(envir)
        @rbEnvir=[envir] 
      end

      def rbenvir_new
        #l'objectif est que comme c'est une méthode toutes les 
        #fonctions de parsing de l'objet sont connues! 
        binding
      end

      def rbenvir_go_to(inRb,envir=nil)
        if inRb
          #puts "rbenvir_go_to #{inRb.inspect}"
          inRb=":new" if ["new","none",":none","nil"].include? inRb
          @rbEnvirs={} unless @rbEnvirs
#p inRb
          @rbEnvirs[inRb]=rbenvir_new if inRb == ":new" or !@rbEnvirs[inRb]
          @rbEnvirs[inRb]=envir if envir and inRb != ":new"
#puts "rbenvir_go_to";p envir
          @rbEnvir.unshift(@rbEnvirs[inRb])
        end
      end

      def rbenvir_back_from(inRb)
        @rbEnvir.shift if inRb
      end

      def rbenvir_ls(rbEnvir=nil)
        rbEnvir=@rbEnvir[0] unless rbEnvir
        rbEnvir=@rbEnvirs[rbEnvir] if rbEnvir.is_a? Symbol
        rbEnvir=@rbEnvir[rbEnvir] if rbEnvir.is_a? Integer
        eval("local_variables",rbEnvir)
      end

      def rbenvir_get(rbEnvir=nil)
        rbEnvir=@rbEnvir[0] unless rbEnvir #the current if nil
        rbEnvir=@rbEnvirs[rbEnvir] if rbEnvir.is_a? Symbol
        rbEnvir=@rbEnvir[rbEnvir] if rbEnvir.is_a? Integer
        rbEnvir
      end

      def rbenvir_current
        @rbEnvirs.keys.select{|b| @rbEnvirs[b]==@rbEnvir[0]}
      end

    end

  end
end
