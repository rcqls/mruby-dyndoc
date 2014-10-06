module Dyndoc
  module MRuby

  class TemplateManager

    def get_klass(klass) 
      return klass.split(",").map{|e| e.strip}
    end
    
    def get_method(call,klass0)
      i,bCall=-1,nil
      klass=klass0+["Object"]
#p call;p klass;p call+"."+klass[i+1];p @calls.keys
      bCall=@calls[call+"."+klass[i+=1]] until bCall or i==klass0.length
      if bCall
        @meth,@klasses= call.dup,klass
        @called = call << "."+ (@meth_klass=klass[i])
      end
      return bCall
    end

    def get_super_method(parent=1)
      (@klasses.map{|e| @meth+"."+e} & @calls.keys)[parent]
    end
    
  end

  module AutoClass

    #be carefull, these objects does not be useable again
    def AutoClass.find(str)
      #declare here the different autodeclaration!
      res={}
      if /^\s*R\:\:([^\:]+)(?:\:(.*))?/ =~ str #for R object (and compatibility)!!!
        res["ObjectName"]={:val=>[$1]}
        res["objR"]={:val=>[($2 and !$2.empty?) ? $2 : $1]}
        res["Class"]={:val=>["class(#{res["objR"][:val]})".to_R.to_a.map{|rclass| "RClass"+rclass.capitalize}.join(",")+",Object"]}
      ######disabled: elsif /^\s*R\((.*)\)\s*$/ =~ str #for R expression
      #   require 'digest'
      #   res["ObjectName"]={:val=>["R"+Digest::SHA1.hexdigest($1)]}
      #   #p [$1,$2]
      #   res["objR"]={:val=>[$1]}
      #   res["Class"]={:val=>["class(#{res["objR"][:val]})".to_R.to_a.map{|rclass| "RClass"+rclass.capitalize}.join(",")+",Object"]}
      # elsif /^\s*(?:Rb|Ruby|rb|ruby)\((.*)\)\s*$/ =~ str
      #   require 'digest'
      #   res["ObjectName"]={:val=>["Rb"+Digest::SHA1.hexdigest($1)]}
      #   res["objRb"]={:val=>[$1]}
      #   res["Class"]={:val=>["RbClass"+res["objRb"][:val].class+",Object"]}
      end   
      p res           
      return res
    end

  end

  end
end
