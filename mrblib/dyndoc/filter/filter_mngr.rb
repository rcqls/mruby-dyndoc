# encoding: utf-8

module Dyndoc

  class FilterManager

    attr_accessor :envir, :rbEnvir, :rEnvir, :outType, :tmpl

    @@letters="_,\\-,\\.,\\@,\\$,\\&,\\%,a-z,0-9,A-Z,à,é,è,ë,ù,ü,ö"
    @@letters_short="_,\\-,\\.,a-z,0-9,A-Z,à,é,è,ë,ù,ü,ö"
    @@start="\\{"
    @@stop="\\}"

    def FilterManager.letters(mode=nil)
      return @@letters unless mode
      return @@letters_short if mode==:short 
    end

    def FilterManager.delim
      [@@start,@@stop]
    end

    def FilterManager.global(tmpl)
      FilterManager.new({:local=>tmpl.global,:global=>tmpl.global},tmpl)
    end

    
    def initialize(envir={},tmpl=nil) #rbEnvir=nil,rEnvir=nil
      @envir=Envir.new(envir)
      @tmpl=tmpl
      @rbEnvir=@tmpl.rbEnvir
      @rEnvir=@tmpl.rEnvir
      @scan=CallScanner.new
    end


    @@options={:required=>:default,:stack=>:post, :mark=>:post, "G"=> :global,"L"=>:local, :prev=>:out,"O"=>:out, :frag =>:pre, "-"=>:pre,"+"=>:post,"?"=>:default}

    def delim=(s)
      case s
      when "{" 
	      @@start="\\{"
        @@stop="\\}"
      when "["
	      @@start="\\["
        @@stop="\\]"
      end
    end
    

# READ AND IMPORT VARIABLES! ##############

######################
# read ordered dict 
######################    
    def FilterManager.eval_options(opts)
      opts=":local" unless opts
      if opts.scan(/^([A-Z\d\?]*[+]?[-]?)$/)[0]
	## Abbreviation
	opts=opts.split("").map{|l| @@options[l]}
      else
	opts=opts.split(",").map{|e| eval(e)}
	## alias
	opts.map!{|e| (@@options[e] ? @@options[e] : e)}
      end
      return opts
    end

    def FilterManager.eval_dict(b,vars=false)
#puts "eval_dict:b";p b
      dict=[]
      key=nil
      first_lines=vars
      newarray=[]
      b.each{|s|
	if first_lines
	  ## list of variables (only for VARS not for CALL and INPUT)
	  res=s.split(",").map{|e| e.strip.scan(/^(\:\:?[\w\._]*\*?)(?:\[(.*)\])?$/)[0]}
	  if res.all?
	    res.map{|k,o| 
	      o=FilterManager.eval_options(o)
	      k=k.strip
	      if k[0,2]=="::"
      		k=k[1..-1]
      		o << :global
	      end
	      if k[-1,1]=="*"
	       k=k[0...-1]
	       o << :array
	       newarray << eval(k)
	      end
	      dict << [eval(k).to_s,["",o]]
	    }
	  else
	    first_lines=false
	  end
	else 
	  first_lines=false
	end
	unless first_lines
	  ## variables initialisation ?
	  key,opts,out,str=s.scan(/^\s*\:(\:?[#{FilterManager.letters}\-\._]*\*?)(?:\[(.*)\])?\s*=(=?)>(.*)/)[0]
#puts "key";p key
	  if key
	    opts=opts.strip if opts
	    opts=FilterManager.eval_options(opts)
	    if key[0,1]==":"
	      key=key[1..-1]
	      opts << :global
	    end
	    if key[-1,1]=="*"
              key=key[0...-1]
	      opts << :array
	      newarray << key
	    end
	    opts << :out unless out.empty? ## "==>" means that opts includes :out
	    str=str.strip
	    ## test if string
	    tmp=str.scan(/^[\"\'](.*)[\"\']$/)[0]
#p tmp
	    str=(tmp ? tmp[0] : str)
	    elt=[str,opts] ## always an Array 
	    dict << [key,elt]
	  else 
	    ## append the line
	    #puts "append the line";p s
	     dict[-1][1][0] += ((dict[-1][1][0]=="") ? "" : "\n")+s
	  end 
	end 
      }
      ##
      dict2=[]
      dict.each{|k,v|
        if (newarray.include? k)
          if(elt=dict2.assoc(k))
            elt[1][0] << v[0]
            elt[1][1] |= v[1]
          else
            dict2 << [k,[[v[0]],v[1]]]
          end
       else
          dict2 << [k,v]
        end
      }
      #deal with whitespace at the beginning and the end of a block!
      dict2.each{|k,v| v[0]=Utils.unprotect_blocktext(v[0]) unless v[0].is_a? Array}
      dict2 
    end 

########################
# import ordered dict to final one!
########################
    def import_dict(dict)
#puts "import_dict:dict";p dict
      dict.each{|k,v|
#puts "import_dict:k,v";p k;p v
	    if k.is_a? Symbol
	      @envir.local[k]=v #for :prev
      #elsif k.is_a? String and k[0,1]=="@"
        #ruby variables
#puts "#{k}";p v
        #p @envir.local
        #TODO: evaluer la variable en tenant compte de la valuer :default! 
        # environnement objet! accessor objet!
	    elsif k.is_a? String
        if v[1] and v[1].include? :array
          v[0].map!{|e| e.replace(apply(e))}
        else
          v[0].replace(apply(v[0]))
        end
	      key=k.to_s
        key=@envir.keyMeth(key)
#puts "import_dict:key=#{key}"
        ## key=toto.1.ta -> key=toto et deps=["1","ta"]
        keys=Envir.to_keys(key)
#puts "import_dict:keys,v";p keys;p v
	      opts=v[1] & [:global,:local,:out]
        ## declaration
	      v[1] -= opts ## always [:global,:local,:out] have to be deleted
	      v=v[0,1] if v[1].empty? ## no option v Array of length 1
        ## set the env
#p opts
	      if opts.include? :out
	        @envir.keys_defined?(keys,:out) ##find the previous
#p self
#p @envir.curenv.__id__;p @envir.local.__id__; p @envir.global.__id__
	        env=@envir.curenv
	      elsif opts.include? :global
	        env=@envir.global
	      else ## the default is local!!! 
	        env=@envir.local
	      end
        ## deal with v[0]
#puts "keys v";p keys;p v
        ## not necessarily a textElt!!!! -> curEnv2 is returned by @envir.elt_defined?(keys2)!
        curEnv2=nil
	      if v[0].is_a? String and v[0].strip[0,1]==":" and (!(keys[-1].is_a? String) or !["@","$"].include? keys[-1][-1,1]) #and !("0".."9").include?(v[0].strip[1,1])
#puts "keys";p keys
#puts "v[0]";p v[0];p v[0].strip[1..-1]
	        keys2=v[0].strip[1..-1]
	        keys2="self"+keys2 if keys2[0,1]=="."
          keys2=Envir.to_keys(keys2)
#puts "keys2:";p keys2
	        keys2,key_extract=Envir.extraction_make(keys2)
#p @envir
          curEnv2=@envir.elt_defined?(keys2)
#puts "curEnv2"; p curEnv2
        elsif v[0].is_a? String and v[0].strip[0,2]=='\:'
          v[0]=v[0].strip[1..-1]
        end
## correction 12/10/08: attr was unfortunately lost for pointer argument!!!!
#puts "import_dict:v (AV)";p v
	      if curEnv2
#puts "v[1]?";p v
	        curAttr=(v[1] ? v[1] : nil)
	        v=Envir.extraction_apply(curEnv2[keys2[-1]],key_extract)
	        v[:attr]=curAttr if curAttr
#puts "v";p v
	      else
	        v=Envir.to_textElt(v)
          #special treatment for ruby variable here
          #puts "vvvvvvvv";p k;p v
          if k[-1,1]=="@"
           v[:rb]=@rbEnvir[0].eval(v[:val][0])
          end
          if k[-1,1]=="$"
            rname=".dynStack$rb"+v.object_id.abs.to_s
            v[:r]=R4rb::RVector.new rname
#p k;p v
            v[:r] << rname
            R4rb << rname+"<-"+ v[:val][0]
          end
          if k[-1,1]=="&"
            jlname="_dynStack_"+v.object_id.abs.to_s
            v[:jl]=Julia::Vector.new jlname
#p k;p v
            v[:jl] << jlname
            Julia << "("+jlname+"="+ v[:val][0]+")"
          end

          if k[-1,1]=="%"
            cmdCode=v[:val][0]
            args=case cmdCode
            when /^jl\:/
              [cmdCode[3..-1],:jl]
            when /^(r|R)\:/
              [cmdCode[2..-1],:r]
            else
              [@rbEnvir[0].eval(cmdCode),:rb]
            end
            ## Dyndoc.warn "args",args
            v[:rb]=Dyndoc::Vector.new([:r,:jl],args[0],args[1],k[0...-1])
#p k;p v
            #v[:rb].replace @rbEnvir[0]eval(v[:val][0])
          end
	      end
	      #special treatment for null array and hash
	      if v.is_a? Hash and v[:val] and ["0[]","0{}"].include? v[:val][0].strip
	        v[:val][0]=v[:val][0].strip
	        v=( v[:val][0][1,1]=="[" ? [] : {} )
	      end
#puts "import_dict:v (AP)";p v
#p Envir.elt_defined?(env,keys)
#puts "keys";p keys
#puts "env";p env
        ## deal with eventual changes
        curEnv=Envir.elt_defined?(env,keys)
#puts "curEnv";p curEnv
#puts "v";p v
        if curEnv  and !(v.is_a? Array) and !(v[:attr] and v[:attr].include? :default)
          curElt=curEnv[keys[-1]]
#puts "curElt";p curElt
          ## key already exists
          if Envir.is_textElt?(curElt)
	          curElt[:attr]=v[:attr] if v[:attr] #change the options (maybe dangerous)
            if curElt[:attr] and curElt[:attr].include? :post
              ## append the content (this is an ANCHOR!!!)
              curElt[:val][0] << "\n" unless curElt[:val][0].empty?
              curElt[:val][0]+=v[:val][0]
            else
              ## change the content
              Envir.update_textElt(curElt,v)
            end
          elsif Envir.is_listElt?(curElt)
#puts "keys";p keys
            #change it! curElt is here curEnv!
#curEnv.each{|k,e| if k!=:prev 
#  puts "curEnv(AV)[#{k}]";p e 
#  end
#}
#puts "curElt(AV)";p curElt
#puts "keys2";p keys2
#puts "v";p v
            #curElt=v
	          curEnv[keys[-1]]=v
#puts "curElt(AP)";p curElt
#curEnv.each{|k,e| if k!=:prev  
#puts "curEnv(AP)[#{k}]";p e 
#  end
#}
          end
	      elsif v.is_a? Hash and v[:attr] and (v[:attr].include? :default)
          ## This is the old tricks!!!
          ## unless (env==@envir.local and @envir.key_defined?(keys[0]))  or (env.include? keys[0] and !env[keys[0]][0].empty?)
          ## This is the new one! 
          # if (env==@envir.local) and !(Envir.elt_defined?(@envir.local,keys))
          # BUT this does not work for CoursProba because of RFig with rcode empty!
          # last try: direct adaptation of the old one  without further thinking!
          if !(env==@envir.local and @envir.elt_defined?(keys)) and !((tmpElt=Envir.elt_defined?(env,keys,true)) and !tmpElt[:val][0].empty?)
            v[:attr] -= [:default]
	          v.delete(:attr) if v[:attr].empty?
            ## create it
	          Envir.set_elt!(env,keys,v)
	        end
	      else
          ## otherwise, create it
#p "ici";p keys;p v
	   
          curElt=Envir.get_elt!(env,keys)
          curElt[keys[-1]]=v if curElt
	        #Envir.set_elt!(env,keys,v)
	      end
#puts "import_dict";p curElt
	    end
    }
  end



###############################
# mode -> nil (normal), :pre (fragment to preprocess), :post (post-processed)
###############################
#     def apply(str,mode=nil,to_filter=true,escape=false)
# Dyndoc.warn "Filter:apply:str",str
#       @mode=mode
#       str=str.gsub(/\\?\#?\##{@@start}[#{@@letters}]+#{@@stop}/) {|w|
#         	if w[0,1]=="\\"
#         	  w[1..-1]
#         	else
#         	  @envir.output(w,mode,escape)
#         	end
#       }
#       if @rbEnvir and @mode!=:pre
# 	     str=RbServer.filter(str,@rbEnvir)
#       end
#       ## very important!! multilines have to be splitted -> flatten is applied just after!!!
#       ## obsolete : str=str.split("\n") if @@start=="\\[" and !str.empty? # "".split("\n") -> [] and not [""]
#       str=str.split("\n") if @mode==:pre and !str.empty?
#       res=(to_filter ? RServer.filter(CallFilter.filter(str,self)) : str)
#       #puts "res";p res
#       res
#     end


    def process(txt,in_type=nil,out_type=nil)
#puts "process:txt";p txt;p in_type
      return txt[1..-1] if txt[0,1]=="\\"
      txt2=txt[(in_type.length+1)..-2] if in_type
      out_type=@outType unless out_type
      out_type="none" unless out_type
      if ["="].include? txt2[0,1]
#p txt2
        out_type+="="
#p out_type 
        txt2=txt2[1..-1]
      end
      @current=txt2
#puts "txt2";p txt2
#p out_type
      case in_type
      when ":",":rb",":Rb","#rb","#Rb"
        #p [:process,@mode,txt2,@rbEnvir[0]]
        return txt if @mode==:pre or !@rbEnvir[0]
        txt2=@tmpl.process_rb(txt2)
        ## Dyndoc.warn ["txt2",txt2]
        res=RbServer.output(txt2,@rbEnvir[0])
#p ["process [rb]",res] #,txt2,@rbEnvir[0],@tmpl.rbenvir_ls(@rbEnvir[0])] if txt2=~/\\\\be/
#Dyndoc.warn "#rb", [@rbEnvir[0],$curDyn.tmpl.rbenvir_current,$curDyn.tmpl.rbenvir_get($curDyn.tmpl.rbenvir_current[0])] if txt2=="toto[i]"
      when ":R","#R"
        return txt if @mode==:pre
        res=RServer.safe_output(txt2,@rEnvir[0])
        if res[0]=='try-error'
          puts "WARNING: #{txt} was not properly evaluated!" if $dyndoc_ruby_mode and $dyndoc_ruby_mode!=:expression
          $dyn_logger.write("ERROR R: #{txt} was not properly evaluated!\n") unless $cfg_dyn[:dyndoc_mode]==:normal
          res=txt 
        end
        #puts "#{txt} in #{@rEnvir[0]} is #{res}"
      when ":r","#r"
        return txt if @mode==:pre
        res=RServer.safe_output(txt2,@rEnvir[0],:pretty=>true)
        if res[0]=='try-error'
          puts "WARNING: #{txt} was not properly evaluated!" if $dyndoc_ruby_mode and $dyndoc_ruby_mode!=:expression
          $dyn_logger.write("ERROR R: #{txt} was not properly evaluated!\n") unless $cfg_dyn[:dyndoc_mode]==:normal
          res=txt 
        end
        #puts "#{txt} in #{@rEnvir[0]} is #{res}"
      when ":jl","#jl"
        return txt if @mode==:pre
        ## puts "#jl:"+txt2
        res=JLServer.output(txt2,:print=>nil)
      when "@"
        return txt if  @mode==:pre
        res=CallFilter.output(txt,self)
      when "#","##"
#p @envir
        #p @envir.output(txt,@mode,@escape)
        #p @envir.output(in_type+"{"+txt2+"}",@mode,@escape)
#puts "txxt2";p txt2
	      if txt2[-1,1]=="?"
	        if res=@envir.extract(txt2[0...-1]) and res.class==String
	          #nothing else to do! res is 
            #p res 
	        else
	          res=""
	        end
	      elsif txt2[0,1]=="#" #fetch the length of the list
	        res=@envir.extract(txt2[1..-1])
          #puts "\#{#{txt2}\}";p res
	        res=(res ? res.length : -1)
	        #res=-1;in_type+"{"+txt2+"}"
	      elsif txt2[0,1]=="?"
	        res=@envir.extract(txt2[1..-1]).class
          #puts "#{txt2[1..-1]}";p res
	        out_type+="=" unless out_type[-1,1]=="="
	        if res==Hash
	          res=:List
	        elsif res==Array
	          res=:Array
	        elsif res==String
	          res=:Text
	        else
	          res=:nil
	        end
#p res
	      elsif txt2[0,2]=="+?"
	        res=@envir.extract(txt2[2..-1])
	        out_type+="=" unless out_type[-1,1]=="="
	        res=(res and res.length>0 ? true : false)
	      elsif txt2[0,2]=="0?"
	        res=@envir.extract(txt2[2..-1])
	        out_type+="=" unless out_type[-1,1]=="="
	        res=(res and res.length==0 ? true : false)
        elsif  /([^@]+@)([^@]*)/ =~ txt2
#puts "ICI";p txt2;p @envir.local;p @envir.extract_raw($1)
          res=@envir.extract_raw($1)[:rb]
#p res
          res=eval("res"+$2) if $2
#p res
        elsif  /([^\$]+\$)([^\$]*)/ =~ txt2 ##and !(txt2.include? "{") #deal with R variable
#puts "ICI";p txt2
#p $1;p @envir.extract_raw($1);p $2
          #if @envir.extract_raw($1)
            res= ( $2.empty? ? @envir.extract_raw($1)[:r].value : (@envir.extract_raw($1)[:r].name+$2).to_R )
          #else
          #  return txt
          #end
          #TO CHANGE!!! res=eval("res"+$2) if $2 #TO CHANGE!!!!
#puts "res R";p res
        elsif  /([^\&]+\&)([^\&]*)/ =~ txt2 ##and !(txt2.include? "{") #deal with R variable
#puts "ICI";p txt2
## p "jl";p $1;p $2 ;p @envir.extract_raw($1)
          #if @envir.extract_raw($1)
            res= ( $2.empty? ? @envir.extract_raw($1)[:jl].value : (@envir.extract_raw($1)[:jl].name+$2).to_jl )
          #else
          #  return txt
          #end
          #TO CHNAGE!!! res=eval("res"+$2) if $2 #TO CHANGE!!!!
#puts "res R";p res
        elsif  /([^\%]+\%)([^\%]*)/ =~ txt2 ##and !(txt2.include? "{") #deal with R variable
#puts "ICI";p txt2
## p "dynArray";p $1;p $2 ;p @envir.extract_raw($1)
          #if @envir.extract_raw($1)
            res= ( $2.empty? ? @envir.extract_raw($1)[:rb].ary : (@envir.extract_raw($1)[:rb].ary+$2) )
          #else
          #  return txt
          #end
          #TO CHNAGE!!! res=eval("res"+$2) if $2 #TO CHANGE!!!!
#puts "res R";p res
        elsif /^([#{FilterManager.letters}]*)\>([#{FilterManager.letters}]*)$/ =~ txt2
          #puts "var>output"
          var,out=$1,$2
          out="out" if out.empty?
          out=out.to_sym
          out_type+="=" unless out_type[-1,1]=="="
          var=@envir.extract_raw(var)
          res=var[out]
        elsif txt2[-1,1]=="!"
          #p "!=exec mode"
          inRb,name=txt2[0...-1].split(":")
          name,inRb=inRb,name unless name
          inRb="new" if inRb and inRb.empty?
#puts "name,inRb";p [name,inRb]
          code=@envir.extract(name)
#p code
          if code
            Utils.escape_delim!(code)
            code="{#document][#main]"+code+"[#}"
#p code
            @tmpl.rbenvir_go_to(inRb)
            res=@tmpl.parse(code,self)
            @tmpl.rbenvir_back_from(inRb)
          else
            res=txt2
          end
#p res
	      else
	        txt2=txt2[0...-1]+tmpl.Fmt if txt2[-1,1]=="#"
#p txt2
	        #depend on out_type!
	        if [":=",":rb=",":Rb=","#rb=","#Rb=",":r=",":R=","#r=","#R="].include? out_type
	          #ruby use!
	          res=@envir.extract(txt2)
	        else
	          #otherwise
            ###puts "iciiii";p txt;p txt2
            ###if txt2.include? "{"
            ###  res=txt
            ###else
	           res=@envir.output(in_type+"{"+txt2+"}",@mode,@escape)
            ###  p res
            ###end
	        end
	      end
      when "#F"
	      #RMK: protection against extraction -> mainly developped to eval dyndoc code inside dyndoc document!
	      txt2=txt2[1..-1].strip if (protect_extract=txt2[0,1]=="!")
#puts "protect_extract";p protect_extract
        res=(File.exist?(txt2) ? File.read(txt2) : "")
#p res
	      res=Utils.protect_extraction(res) if protect_extract
#puts "#F:#{txt2}";p res;p out_type
      when ""
        return txt
      end
#puts "instr:";p txt;p in_type
#puts "res to convert?";p res;p out_type
#puts "convert";p convert(res,out_type)
## Dyndoc.warn "res", [out_type,res]
      return convert(res,out_type)
    end

    def convert(res,out_type=nil,in_type=nil)
##puts "convert:";p [res,out_type]
      return res unless out_type
      case out_type
      when ":=",":rb=",":Rb=","#rb=","#Rb="
        #if res.is_a? String
        #  res.inspect
        #else res.is_a? Array
#puts out_type;p res;p res.inspect
        #if res.is_a? Array and res.length==1 and res[0].is_a? String
        #  res[0].inspect
        #else
          res.inspect
        #end 
      when ":",":rb",":Rb","#rb","#Rb"
#puts "convert [rb]:";p res
        if res.is_a? Array
          res.join(", ")
        else 
          res.to_s
        end 
      when ":R=","#R=",":r=","#r="
        if res.is_a? Array
          res2="c("+res.map{|e| "'"+e.to_s+"'"}.join(",")+")"
          res2.gsub!(/\\/,'\\\\\\\\')
          #p res2
          res2
        else
          "'"+res.to_s+"'" #QUESTION???? .gsub(/\\/,'\\\\\\\\')
        end 
      when ":R","#R",":r","#r"
        if res.is_a? Array
          res.join(",")
        else
          res.to_s
        end
      when ":jl","#jl"
        if res.is_a? Array
          res.join(",")
        else
          res.to_s
        end
      when "=","@=","#=","##=" ,"none="
#puts "convert [=]";p res
        if res.is_a? Array
          res.join(",")
        else
          "\""+res.to_s+"\""
        end 
      when "","@","#","##","none","#F"
        if res.is_a? Array
          res.join(",")
        else
          res.to_s
        end 
      end
    end

    # def apply(str,mode=nil,to_filter=true,escape=false)
    #   ##return str unless to_filter
    #   ##RMK: to_filter unused!
    #   @mode,@escape=mode,escape 
    #   #puts "str to apply filter";p str
    #   @scan.tokenize(str)
    #   ext=@scan.extract
    #   #p ext
    #   res=@scan.rebuild_after_filter(ext,self)
    #   #res=res.split("\n") if @mode==:pre and !res.empty?
    #   #puts "res";p res
    #   res
    # end

    def apply(str,mode=nil,to_filter=true,escape=false)
      #Dyndoc.warn 
      #p "apply:str:"+str
      ##return str unless to_filter
      ##RMK: to_filter unused!
      @mode,@escape=mode,escape 
      res=""
      str2=str.split(Dyndoc::AS_IS)
      #p str2
      str2.each_with_index do |code,i|
        #Dyndoc.warn 
        #p "apply:code"+i.to_s+':'+code
        if i%2==0
          #Dyndoc.warn "apply:code2",code
          @scan.tokenize(code)
          ext=@scan.extract
          #Dyndoc.warn "apply:ext",ext
          res2=@scan.rebuild_after_filter(ext,self)

          res << res2 
        else
          res << Dyndoc::AS_IS+code+Dyndoc::AS_IS
        end
        #Dyndoc.warn 
        #p "apply:res:"+res
      end
      # if str.split(Dyndoc::AS_IS).length>1
      #   Dyndoc.warn "str to apply",str
      #   Dyndoc.warn "res",res
      # end
      #Dyndoc.warn 
      #p "apply:res2:"+res
      res
    end


  end

  AS_IS='UnfltrdAsIsBlck' #strange unmeaning term to protect in a filter.apply block!

end
