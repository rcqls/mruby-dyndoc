# encoding: UTF-8

module Dyndoc
  module MRuby

  class TemplateManager

    def eval_TXT(b,filter,strip=@strip)
      b.delete_if{|s| !s.scan(/^\s*%%%/).empty?} unless @echo>0
      if b.length>0
        txt=b.map{|l|
	  l2=filter.apply(l)
	  if (l.strip).scan(/^\#\{.*\}$/).empty?
	    l2
	  else
            ## do not deal with empty result!!!
	    l2 unless l2.empty?
	  end
        }.compact
#p "txt";p txt
        txt.map!{|l| l.lstrip} if strip
#p "txt2";p txt
        txt=txt.join("\n")
      else
        txt=nil
      end
      return txt
    end

     def eval_VARS(b,filter)
      ## apply R filtering
      ##b=b.map{|e| filter.apply(e)} -> apply to each line!!
      ## read the bloc
      dict=FilterManager.eval_dict(b,true)
#puts "eval_VARS:dict";p dict
      filter.import_dict(dict)
#puts "eval_VARS:filter";p filter.envir.local
     end
 
    def eval_BINDING(env,b,filter)
      eval_VARS(b,filter)
      @envirs[env]=filter.envir.local
#p "BINDING#{env}";p filter; p "\n"
    end
 
    def eval_PARENT(env,filter)
      filter.envir.local[:prev]=@envirs[env] if @envirs[env]
#p "PARENT#{env}";p filter; p "\n"
    end
 
    def eval_ENVIR(env,filter)
      filter.envir.local=@envirs[env] if @envirs[env]
#p "ENVIR#{env}";p filter; p "\n"
    end
 
    def eval_SET(var,txt,filter,newline=nil)
      ## apply R filtering
#puts "SET";p var; p txt
      key=filter.apply(var)
      key,opt=key.scan(/([#{FilterManager.letters}]+)\s*(!?\+?\??)/).flatten
      key=filter.envir.keyMeth(key)
#puts "SET:key";p key;p Envir.to_keys(key);p opt
#p filter.envir.local
#p filter.envir.elt_defined?(Envir.to_keys(key))
      txt=filter.apply(txt)
#puts "SET:txt";p txt
      curElt=((opt.include? "!") ?  filter.envir.elt_defined?(Envir.to_keys(key),true) :  Envir.elt_defined?(filter.envir.local,Envir.to_keys(key),true) )
#puts "curElt"; p curElt
#puts "curElt if opt?"; p curElt if opt.include? "?"
      return if curElt and opt.include? "?"
      if key and curElt 
        if opt.include? "+"
          curElt[:val][0] << txt
        else
          txt=[txt] if curElt[:attr] and curElt[:attr].include? :array
          curElt[:val][0] =txt
        end
        curElt[:val][0] << "\n" if newline and !(curElt[:attr] and curElt[:attr].include? :array)
      else
        #unless ! in opt only local 
        key=":"+key unless opt.include? "!"
#puts "SET:new key";p key;p txt
        filter.envir[key]=txt
      end
    end

    def eval_RCODE(code,filter,opts={:pretty => true}) #pretty=true,capture=nil)
#Dyndoc.warn "eval_RCODE",code
#Dyndoc.warn "rEnvir[0]",@rEnvir[0] #;"print(ls(.env4dyn$#{@rEnvir[0]}))".to_R
#Dyndoc.warn "output",RServer.output(code.strip,@rEnvir[0],pretty)
      Utils.clean_eol!(code)
      #puts "eval_RCODE";p [code ,@rEnvir[0]]
      #p RServer.safe_output(code,@rEnvir[0],opts)
      return filter.convert(RServer.safe_output(code,@rEnvir[0],opts),"#")
    end

    def eval_rout(code,filter)
      code=Utils.clean_eol!(code)
      return RServer.rout(code,@rEnvir[0])
    end
 
    def eval_RbCODE(code,filter,opts={})
#p @rbEnvir[0];p filter.apply(code)
#puts "code";p code
      if code[0,1]=="<"
	      i=(code=~/>/)
	      envir,code=code[1...i],code[(i+1)..-1]
#p envir
#p code
	      envir=(envir.empty? ? TOPLEVEL_BINDING : eval(envir))
#p envir
        opts[:error] = "RbCode Error"
	      return filter.convert(RbServer.output(code,envir,opts),"#")
      else
        opts[:error] = "RbCode Error"
	      return filter.convert(RbServer.output(code,@rbEnvir[0],opts),"#")
      end
    end
 
    def eval_INPUT(tmpl,b,filter)
      ## register tmpl in @blocks to avoid next the same call!!!
#=begin TO REMOVE
      tmpl,tags,rest=tmpl.split(/\((.*)\)/)
      tags=TagManager.init_input_tags(tags.split(",").map{|e| e.strip.downcase}) if tags
#=end
      tmpl,export=tmpl[0...-1],true if tmpl[-1,1]=="!"
#p tmpl;p tags;p rest
      tmpl_name=tmpl
      tmpl_orig=Dyndoc.doc_filename(tmpl.strip)
      tmpl=Dyndoc.directory_tmpl? tmpl_orig
      #TO REMOVE: init_dtag(tmpl)
#p tmpl
      block=tmpl #TO REMOVE: +(partTag.empty? ? "" : "("+partTag.join(',')+")")
      unless @blocks.keys.include? block
        #TO REMOVE: input=PartTag.part_doc(File.read(tmpl),partTag2)
#puts "inside INPUT";p tmpl
        return "Dyndoc Error: "+tmpl_name+" is not reacheable!!! " unless tmpl
      	input=Dyndoc.read_content_file(tmpl,{:doc => @doc})
      	@blocks[block]=input
#p block;p @blocks[block]
      end
      ## apply R filtering
      b2=b.map{|e| filter.apply(e)} if b.length>0
      dict2={:prev=>filter.envir.local}
      if b.length>0
      	dict=FilterManager.eval_dict(b2) ###eval("{"+b2.join(",")+"}")
      	dict.each{|k,v| dict2[k.to_s]=v}
      end
      filter2=FilterManager.new({:global=>@global},self)
      filter2.import_dict(dict2)
      ###################################
      # added to set the current filename 
      # of the template in the local environment
      # _FILENAME_ is maybe obsolete now 
      # (see also "parse" in parse_do.rb file)
      ###################################
      filter2.envir["_FILENAME_CURRENT_"]=tmpl.dup
      filter2.envir["_FILENAME_"]=tmpl.dup #register name of template!!!
      #####################################
      filter2.envir["_FILENAME_ORIG_"]=tmpl_orig.dup #register name of template!!!
      filter2.envir["_PWD_"]=File.dirname(tmpl) #register name of template!!!
# #=begin
#       Envir.set_textElt!(["_FILENAME_"],tmpl.dup,filter2.envir.local) #register name of template!!!
#       Envir.set_textElt!(["_PWD_"],File.dirname(tmpl),filter2.envir.local) #register name of template!!!
# #=end
      ## Text part
      ## pre-filtering
      b2=@blocks[block]
      @current_tmpl=block
#puts "eval_INPUT:tags";p tags
      txt=parse(b2,filter2,tags)
#puts "eval_INPUT:txt";p txt
      ## post-filtering
      txt=filter2.apply(txt,:post,false)
      txt.strip! ##clean whitespace 
      txt += "\n" ##need one at the end!!!
      filter.envir.local=filter2.envir.local if export
      return txt
    end
 
    def eval_LOAD(b,filter)
      ## just load and parse : read some FUNCs and EXPORT some variables
      ## in the header
      if b.length>0
        b2=b.map{|e| filter.apply(e)}
#puts "b2";p b2
#Dyndoc.warn "LOAD",b2
        b2.each{|lib|
          lib,tags,rest=lib.split(/\((.*)\)/)
#p lib;p tags;p rest
          tags=tags.split(",").map{|e| e.strip.downcase} if tags
#puts "lib";p lib
          tmpl_orig=Dyndoc.doc_filename(lib.strip)
          tmpl=Dyndoc.directory_tmpl? tmpl_orig
#puts "tmpl";p tmpl

      	  # REPLACEMENT of  ABOVE!
      	  unless @libs.keys.include? tmpl
      	    input=Dyndoc.read_content_file(tmpl)
      	    @libs[tmpl]=input
      	    filter.envir["_FILENAME_"]=tmpl.dup #register name of template!!!
      	    filter.envir["_FILENAME_ORIG_"]=tmpl_orig.dup #register name of template!!!
      	    filter.envir["_PWD_"]=File.dirname(tmpl) #register name of template!!!
      	    txt=parse(@libs[tmpl],filter,tags)
      	  end
        }
      end 
    end

    def eval_LOAD_HELPERS(b,filter)
      ## just load and parse
      ## in the header
      if b.length>0
        b2=b.map{|e| filter.apply(e)}
#p b2
        pathenv=File.read(File.join(Dyndoc.cfg_dir[:home],"helpers")).strip
        helpers = ""
        
        b2.each{|lib|
#p lib
          filename=lib.strip
          unless filename[0,1]=="#"
            dirname,filename=File.split(filename)
            filename=File.basename(filename,"*.rb")+".rb"
            filename=File.join(dirname,filename) unless dirname=="."
#p filename
#p pathenv
            filename2=Dyndoc.absolute_path(filename,pathenv)
#puts "names";p names
            if filename2
	            helpers << File.read(filename2) << "\n"
            else
              puts "WARNING: helper #{filename} is unreachable in #{pathenv}!"
            end 
          end
        }
#p helpers
        Dyndoc::MRuby::Helpers.module_eval(helpers)
      end 
    end
 
    def eval_FUNC(bloc,b)
      bloc,code=Utils.end_line(bloc,b)
##p bloc;p code
      key,args=bloc.strip.split(/[|:]/)
      key.strip!
#p "@calls[#{key}]"
      @args[key]=args.split(",").map{|e| e.strip} if args
#p @args[key];p code
      @calls[key]=code
    end
 
    def eval_CALL(call,b,filter,meth_args_b=nil,blckcode=nil)
      txt=""
#puts "eval_CALL:call,b,filter,@calls";p call;p b
#p filter.envir
#p @calls
#p @calls.keys.sort
#puts "meth_args_b"; p meth_args_b
      call,export=call[0...-1],true if call[-1,1]=="!"
      if @calls.keys.include? call
        # envir task
	      b2=b.map{|e| filter.apply(e)} if b and b.length>0
#puts "b2 init";p b2
	      dict2={:prev=>filter.envir.local}

	      if b and b.length>0
#puts "b2";p b2;p b2.map{|e| e.split("\n")}.flatten
	        dict=FilterManager.eval_dict(b2.map{|e| e.split("\n")}.flatten)
#puts "dict";p dict
	        dict.each{|k,v| 
	          dict2[k.to_s]=v
	        }
	      end
#puts "dict2";p dict2
#p dict2["envir"] #if dict2["envir"]
        ## local consideration: special ":envir"
        dict2[:prev]=@envirs[dict2["envir"][0]] if dict2["envir"] and (dict2["envir"][1].include? :local) and @envirs[dict2["envir"][0]] and (@envirs[dict2["envir"][0]].is_a? Hash)
#p dict2 if dict2["envir"] and (dict2["envir"][1].include? :local) and @envirs[dict2["envir"][0]] and (@envirs[dict2["envir"][0]].is_a? Hash)
#puts "CALL:#{call}";p @global
#puts "dict2[\"envir\"]?";p dict2
        # new filter to evualate the call
	      filter2=FilterManager.new({:global=>@global},self)

#puts "filter2.envir";p filter2.envir

        # init body call
        bCall=@calls[call]
        #is a method ? 
        tmpCall=call.split(".")
        isMeth=(bCall==:meth) or (tmpCall.length==2 and (@meths.include? tmpCall[0]))
        # assign self if exists in :prev?
#puts "Assign";p dict2["self"]; p dict2[:prev]
#puts "isMeth?";p isMeth
        if isMeth and dict2["self"]
#puts "dict2";p dict2 
#and dict2[:prev][objName=dict2["self"][0]]
          objName=dict2["self"][0]
#puts "objName";p objName
          objName=objName[1..-1] if objName[0,1]==":"
          objName="self"+objName if objName[0,1]=="."
#puts "objName2";p objName
          #filter2.envir.local["self"]=dict2[:prev][objname]
          objKeys=Envir.to_keys(objName)
#puts "objKeys";p objKeys
#puts "dict2[:prev]";p dict2[:prev]
#puts "Envir.keys_defined.";p Envir.keys_defined?(dict2[:prev],objKeys)
	  # RMK: 5/9/08 it seems that Envir.get_elt! is only used here and replaced by Envir.keys_defined? newly created!
	  #Envir.get_elt!(dict2[:prev],objKeys)

	        # find in dict2[:prev] and their sub :prev
	        dictObj=dict2[:prev]
	        begin
	          objEnv=Envir.elt_defined?(dictObj,objKeys)
	          dictObj=dictObj[:prev]
	        end while !objEnv and dictObj
#p @klasses  
#p @global
#puts "objEnv(local)";p objEnv
	        # otherwise, find in @global envir
	        objEnv=Envir.elt_defined?(@global,objKeys) unless objEnv
#puts "objEnv(global)";p objEnv 
	        # otherwise return empty env
	        objEnv={} unless objEnv
#puts "objEnv";p objEnv #at least {} and then nonempty!
#puts "objKeys[0]";p objKeys[0]
          if objKeys[0]=="self"
#p dict2
#p @vars
            objName=([dict2[:prev]["self"]["ObjectName"][:val][0]]+objKeys[1..-1]).join(".")
#puts "objName4Self";p objName 
          end
##PB HERE: objEnv does not return the right envir because the object is in :prev and then objEnv[objKeys[-1]] is not correct!
# filter2.envir.local["self"] is then unset!
#puts "objKeys[-1]";p objKeys[-1]
#puts "objEnv";p objEnv
#p objEnv[objKeys[-1]]
          filter2.envir.local["self"]=objEnv[objKeys[-1]] 
#puts 'filter2.envir.local["self"]';p filter2.envir.local["self"]
          dict2.delete("self")
#puts "dict2Self";p dict2

          #attempt of autobuilding of object! (10/03/08)
          elt={}
          #test if it is an internal Dyn Object (DynVar, Array, ) i.e. if Class is a field?
#puts "filter2.local";p filter2.envir.local["self"]
          if !objEnv.empty? and filter2.envir.local["self"]
	          if filter2.envir.local["self"].is_a? Array #is an Array object
	            elt["content"]=objEnv[objKeys[-1]]
	            elt["Class"]={:val=>["Array,Object"]}
            elsif !filter2.envir.local["self"]["Class"] #no Class specified => A DynVar or List object 
	            if filter2.envir.local["self"][:val] #is a DynVar object
		            elt["content"]= filter2.envir.local["self"]
		            elt["Class"]={:val=>["DynVar,Object"]}
	            else #is a List object
#puts "List";p objEnv[objKeys[-1]]
		            elt["content"]=objEnv[objKeys[-1]]
		            elt["Class"]={:val=>["List,Object"]}
	            end
	          end
	          elt["ObjectName"]={:val=>[objName]} unless elt.empty?
#puts "class";p elt["Class"]
#puts "content";p elt["content"]
          end
          if objEnv.empty? or !filter2.envir.local["self"]
            if (elt=AutoClass.find(objName)).empty? 
              #is a String Vector i.e. of the form 
              # name1,name2,...,nameN
              vals=objName.split(",").map{|e| e.strip}.map{|e| {:val=>[e]}}
	            elt["content"]={"value"=>{:val=>[objName]},"ary"=>vals}
              elt["Class"]={:val=>["String,Object"]}
	            elt["ObjectName"]={:val=>[nil]} #empty ObjectName used in inspect method!
            end
          end
#puts "Elt:";p elt
          #creation of the new object!
          filter2.envir.local["self"]=elt unless elt.empty?
#p filter2.envir.local
          filter2.envir.local["self"]["ObjectName"]={:val=>[objName]} unless objName=="self" or filter2.envir.local["self"]["ObjectName"]
        end
#puts "filter2";p filter2.envir
#puts "dict2[:prev](???)";p dict2[:prev]
	      #Really IMPORTANT: for pointer tricks: first import :prev environment 
	      filter2.import_dict({:prev=>dict2[:prev]})
	      dict2.delete(:prev)
#puts "dict2";p dict2
#puts "filter2a";p filter2.envir
	#Really IMPORTANT: and then pointers could be recognized!
        filter2.import_dict(dict2)
#puts "filter22";p filter2.envir

        inR=nil
        if isMeth
          if bCall==:meth
#p filter2.envir
#puts "extract self";p call;p filter2.envir.extract("self")

#ICI: tester si l'objet a un champ Klass sinon faire comme avant et le déclarer en 

            klass=get_klass(filter2.envir.extract("self")["Class"])
#puts "call";p call
#puts "klass";p klass
#p @calls.keys
# #=begin
#             i,bCall=-1,nil
#             bCall=@calls[call+"."+klass[i+=1]] until bCall
#             call+="."+klass[i]
# #=end
            bCall=get_method(call,klass)
#puts "call meth";p call;p klass
#p bCall
            #puts some raise Error! return "" unless bCall
	          unless bCall
	            puts "DYN WARNING: Method #{call} undefined for class #{klass} (object: #{objName})"
	          return ""
	        end
          #init the parameter of the true method!
          if (args=@args[call])
              args=args[1..-1]
              args=nil if args.empty? 
#p args

              if meth_args_b
#puts "ICI1";p meth_args_b
                CallFilter.parseArgs(call,meth_args_b,true)
#puts "eval CALL meth_b";p call;p meth_args_b

#p meth_args_b
                b2=meth_args_b.map{|e| filter.apply(e)} if meth_args_b and meth_args_b.length>0

#puts "call(2)";p call;p b2
                dict=FilterManager.eval_dict(b2)
#puts "dict(eval_CALL)";#p dict
#IMPORTANT: (19/10/08) remove self from dict because already imported!
            		dict.map!{|e| e if e[0]!="self"}.compact!

#puts "Import dict in filter2"
#p dict
#puts "eval_CALL:filter2.envir";p filter2.envir
                filter2.import_dict(dict) 
#puts "self";p filter2.envir.local["self"]
#p filter2.envir.local
              end
            end
          end

          # R envir
          inR=filter2.envir.extract("self")["Renvir"]
#p inR

#p @args[call]
#p b2
#p filter2
        end
	# deal with blckcodes
#puts "<<def_blck #{call}"
#p blckcode
#puts "av:";p @def_blck
        @def_blck << blckcode if blckcode and !blckcode.empty?
#puts "ap:";p @def_blck
#p blckcode

        ## Tex part
        ### this is wondeful (10/08/04)
        ## apply filter2 for fragment before parsing
        @rEnvir.unshift(inR) if inR
# #=begin
# if call=="new.TotoIn"
# puts "AVANT"
# p bCall
# p filter2.envir.local["self"]
# end 
# #=end
	# deal with _args_ argument 
#puts "filter2.local";p filter2.envir.local
#p filter2.envir.local["_args_"]
#p Envir.is_listElt?(filter2.envir.local["_args_"])
	if filter2.envir.local["_args_"] and Envir.is_listElt?(filter2.envir.local["_args_"])
#puts "IICCII"
	  filter2.envir.local["_args_"].each{|key,val| filter2.envir.local[key]=val}
	  filter2.envir.local.delete("_args_")
	end
#puts "filter2.local";p filter2.envir.local
#puts "bCall";p bCall
#puts "call binding";p filter2.envir.local
#Dyndoc.warn "rbEnvir tricks", [filter2.envir.extract("binding"),@rbEnvir4calls]
  inRb=filter2.envir.extract("binding") #first the call parameter
  inRb=@rbEnvir4calls[call] unless inRb #second, the tag binding
  rbenvir_go_to(inRb)
#puts "eval_CALL:bCall";p bCall
	txt=parse(bCall,filter2)
#puts "eval_CALL:txt";p txt
  rbenvir_back_from(inRb)
#p filter2.envir.local
# #=begin
# if call=="new.TotoIn"
# puts "APRES"
# p filter2.envir.local["self"]
# end
# #=end
#puts ">>def_blck #{call}"
#puts "av";p @def_blck;p blckcode
        @def_blck.pop if blckcode and !blckcode.empty?
#puts "ap";p @def_blck;
        ## post-filtering
	txt=filter2.apply(txt,:post,false) ##IMPORTANT: EST-CE VRAIMENT UTILE??? VOIR vC!!!!
        @rEnvir.shift if inR
	filter.envir.local=filter2.envir.local if export
      end
#puts "FIN CALL" 
     return txt
    end

    def eval_func(call,code,rbEnvir)
##p call;p code
      key,args=call.strip.split(/\|/) #no longer ":"
      key.strip!
#p "@calls[#{key}]"
      @args[key]=args.split(",").map{|e| e.strip} if args
#p @args[key];p code
      @calls[key]=code
      @rbEnvir4calls={} unless @rbEnvir4calls
      @rbEnvir4calls[key]=rbEnvir if rbEnvir
#p @rbEnvir4calls
    end

    def eval_meth(call,code)
#p call
      key,args=call.strip.split(/\|/) #no longer ":"
      args=(args ? "self,"+args : "self")
      key.strip!
      key2,klass=key.split(".")
#p "@calls[#{key}]"
#p key2;p klass
      @args[key]=args.split(",").map{|e| e.strip}
#p @args[key]
#p code
      @calls[key]=code
      #this is a method!
      @calls[key2]=:meth 
      @meths << key2
      @meths.uniq!
#p @meths
      @args[key2]=["self"]
# #=begin
#       #update method parameters
#       if @args[key2]
#         #update (only the first common parameters, the rest have to be named to be used)
#         ok=true
#         @args[key2]=(0...([@args[key].length,@args[key2].length].min)).map{|i| ok&=(@args[key][i]==@args[key2][i]);@args[key][i] if ok }.compact
#       else
#         #first init
#         @args[key2]=@args[key]
#       end
#=end
#p @calls
#puts "args[new]";p @args["new"]
#p @meths
    end 

    def eval_GLOBALVAR(var,txt,filter,mode="")
      return unless filter.envir.global[var]
      ## texvar already declared in DefaultPre_tmpl.tex
      if mode.empty? or !(["add","append","+"].include? mode)
        filter.envir.global[var][:val][0]=""
      else
         filter.envir.global[var][:val][0] << "\n" unless filter.envir.global[var][:val][0].empty?
      end
      filter.envir.global[var][:val][0] << txt
    end

  end

  end
end
