# encoding: UTF-8

## TODO: .force_encoding("utf-8") needs to be added (see server.rb)
module Dyndoc

  def Dyndoc.vars=(vars)
    @@vars=vars
  end
  
  def Dyndoc.vars
    @@vars
  end
  
  module MRuby

  class TemplateManager

    @@depth=0

    @@cmd=["newBlck","input","require","def","func","meth","new","super","blck","do","if","for","case", "loop","r","renv","rverb","rbverb","jlverb","rout","rb","var","set","hide","format","txt","code","<","<<",">","eval","ifndef","tags","keys","opt","document","yield","get","part","style"]
    ## Alias
    @@cmdAlias={"unless"=>"if","out"=>"do","r<"=>"r","R<"=>"R","rb<"=>"rb","r>"=>"r","R>"=>"R","rb>"=>"rb","m<"=>"m","M<"=>"m","m>"=>"m","M>"=>"m","jl>"=>"jl","jl<"=>"jl","<"=>"txt","<<"=>"txt",">"=>"txt","code"=>"txt","dyn"=>"eval","r>>"=>"rverb","R>>"=>"rverb","rout"=>"rverb","rb>>" => "rbverb","jl>>" => "jlverb","saved"=>"blck","blckAnyTag"=>"blck"}
    @@cmd += @@cmdAlias.keys

    def add_dtag(dtag,cmdAlias=nil)
      @scan=DevTagScanner.new(:dtag) unless @scan
      if dtag
	      @scan.merge_tag(dtag)
	      @@cmd += dtag[:instr]
      end
      if cmdAlias
        @@cmdAlias[dtag[:instr][0]]=cmdAlias
      end
    end

    ## insert text between start and stop marks
    ## the text is automatically loaded from
    def parse(texblock,filterLoc=nil,tags=nil)
      #Dyndoc.warn "texblock",texblock
      @scan=DevTagScanner.new(:dtag) unless @scan
      @varscan=VarsScanner.new(:vars) unless @varscan
#STDOUT.flush
#Dyndoc.warn [:ici]
      if texblock.is_a? String
        ## Dyndoc.warn "parse",texblock
        if @@interactive or $cfg_dyn[:atom_session] ## TODO => atom-interactive
          Utils.parse_dyn_block_for_atom!(texblock)
        else 
          ##disabled: Utils.parse_raw_text!(texblock,self)
        end
        #puts "After parse_raw_text";p texblock
        #puts "raw_key and raw_text";p Utils.dyndoc_raw_text
        #escape accolade every time a new text is scanned!
        texblock=Utils.escape!(texblock,CHARS_SET_FIRST)
        texblock=Utils.clean_bom_utf8!(texblock)
        Utils.silence_warnings do 
          texblock=@scan.process("{#document][#content]" + texblock + "[#}")
        end
        ## else
        ##  Dyndoc.warn "parsed",texblock
      end
 
      unless filterLoc
	      filterLoc=FilterManager.new({:global=>@global},self)
        filterLoc.envir["_FILENAME_CURRENT_"]=@filename.to_s if @filename
	      Envir.set_textElt!(filterLoc.envir.global,["_FILENAME_"],@filename.to_s) if @filename
	      Envir.set_textElt!(filterLoc.envir.global,["_FILENAME_ORIG_"], @tmpl_cfg[:filename_tmpl_orig].to_s) if @tmpl_cfg[:filename_tmpl_orig]
	      Envir.set_textElt!(filterLoc.envir.global,["_PWD_"],Dir.pwd) if @filename
#puts "filterLoc";p @filename;p filterLoc.envir["_PWD_"]
      end
      $dyndoc_currentRoot=filterLoc.envir["_PWD_"]
      ##partTag tricks
      tagsOld=@tags.dup if tags #save @tags
      @tags+=tags if tags

      @vars,varsOld=filterLoc.envir,@vars
      Dyndoc.vars=@vars
      @filter=filterLoc unless @filter ##root filter
      out=[] #change because of immutability of String in Opal
#p texblock
      texblock.map{|b| 
        cmd=b[0].to_s
        #p b if cmd=="blck"
        @curCmd=cmd
        cmd=@@cmdAlias[cmd] if @@cmdAlias.keys.include? cmd
#puts "parse:cmd,b";p cmd;p b
        @@depth+=1
        ###TO temporarily AVOID RESCUE MODE: 
        ##if true; method("do_"+cmd).call(out,b,filterLoc); else
        #puts "ii";p [cmd,out,b[1..-1]]
        if false; send ("do_"+cmd).to_sym,out,b,filterLoc; else
        begin
          #method("do_"+cmd).call(out,b,filterLoc)
          send ("do_"+cmd).to_sym,out,b,filterLoc
          ## Dyndoc.warn [:out,out] if cmd=="eval"
        rescue
          puts "=> Leaving block depth #{@@depth}: "
          codeText=b.inspect
          nbChar=($cfg_dyn and $cfg_dyn[:nbChar_error]) ? $cfg_dyn[:nbChar_error] : 80
          if codeText.length > nbChar
            codeText=codeText[0..((nbChar*2/3).to_int)]+" ...... "+codeText[(-(nbChar/3).to_int)..-1]
          end
          puts codeText
          if @@depth==1
            puts "=> Exiting abnormally!\n"         
            raise SystemExit
          else
            raise RuntimeError, "Dyn Runtime Error"
          end
        ensure
          @@depth -= 1
        end 
        ###TO temporarily AVOID RESCUE MODE: 
        end
      }
      ##restore old partTag and vars
      @tags=tagsOld if tags
      @tags.uniq! 
      @vars=varsOld
      Dyndoc.vars=@vars
#p [:out,out] if @curCmd=="dyn"
      return out.join("")
    end

    # same as parse except that input is a string and the filterLoc is the current one.
    # Rmk: used in String::to_dyn
    def parse_string(input,filterLoc=@filter,tags=[])
      init_tags(input)
      txt=input
      return parse(txt,filterLoc,tags)
    end

    def parse_args(blck,filter)
      ## Dyndoc.warn "parse_args",blck
      parse(blck[1..-1],filter)
    end

    def eval_args(blck,filter)
      @rbEnvir[0].eval(parse(blck[1..-1],filter))
    end

    def next_block(blck,i)
      b=[]
      while (i+1<blck.length and blck[i+1].is_a? Array)
       i+=1
       b << blck[i]
      end
      return b.unshift(i)
    end

    def next_block_until(blck,i,tagset)
      b=[]
      while (i+1<blck.length and !(tagset.include? blck[i+1]))
       i+=1
       b << blck[i]
      end
      return b.unshift(i)
    end

    def next_block_while(blck,i,tagset)
      b=[]
      while (i+1<blck.length and (tagset.include? blck[i+1]))
       i+=1
       b << blck[i]
      end
      return b.unshift(i)
    end

    def do_do(tex,blck,filter)
      i=-1
      begin 
        case blck[i+=1]
          when :do,:<
            i,*b2=next_block(blck,i)
            parse(b2,filter)
          when :out,:>
            i,*b2=next_block(blck,i)
            tex << parse(b2,filter)
          when :nl,:"\\n"
            i,*b2=next_block(blck,i)
            tex << "\n" << parse(b2,filter)
        end
      end while i<blck.length-1
    end

# =begin
#     def get_named_blck(b2,filter)
#       vars=nil #default: no named block!
#       if b2[0][0]==:named
#         vars=filter.apply(b2[0][1].strip)
#         vars.gsub!("#",@Fmt)
#         b2=b2[0][2..-1]
#         if vars[0,1]==">"
#           fmts,vars=vars[1..-1].split(":")
#           b2=nil unless  fmts.split(",").map{|e| e.strip}.include? @fmt
#         else
#           #if a variable ends with FORMATS element
#           if (ind=vars.rindex(/(#{Dyndoc::FORMATS.join("|")})$/))
#             #do not evaluate unless right format
#             b2=nil unless vars[ind..-1]==@Fmt
#           end
#         end
#       end
# p [vars,b2]
#       return [vars,b2]
#     end
# =end

    #new syntax: [#>] tag1,tag2,... > var [...]
    def get_named_blck(b2,filter)
      vars=nil #default: no named block!
      if b2[0][0]==:named
        vars=filter.apply(b2[0][1].strip)
        vars=vars.gsub("#",@Fmt)
        b2=b2[0][2..-1]
        if vars.include? ">"
          fmts,vars=vars.split(">")
          b2=nil unless  fmts.split(",").map{|e| e.strip}.include? @fmt
	  #TODO: changer et mettre la condition sur les tags!!!! et non uniquement sur le format!
	  #HOWTO: b2 non nil s'il existe un document pour lequel cette partie est à évaluer!
        else
          # disabled:
          # #if a variable ends with FORMATS element
          # if (ind=vars.rindex(/(#{Dyndoc::FORMATS.join("|")})$/))
          #   #do not evaluate unless right format
          #   b2=nil unless vars[ind..-1]==@Fmt
          # end
        end
      end
      return [vars,b2]
    end

    def get_named_blck_simple(b2,filter)
      vars=nil #default: no named block!
      if b2[0][0]==:named
        vars=filter.apply(b2[0][1].strip)
        b2=b2[0][2..-1]
      end
      return [vars,b2]
    end

    def make_named_blck(tex,filter,vars,b2,bang=false)
Dyndoc.warn "make_named_blck:b2",b2#[0]
      val=parse(b2,filter)
#puts "make_named_blck:val";p val
      # NB: bang is processed only at the end and not in the recursive process of parsing!
      # The reason is that maybe the form <NAME>! is not correct in some old document!
#Dyndoc.warn "make_named_blck:val",[val,process_bang(val),filter.rbEnvir] if bang
#DEBUG ONLY: val2=val if bang
      val=parse(process_bang(val),filter) if bang
#Dyndoc.warn "make_named_blck:val2",[val2,val]      if bang
      val=Utils.format_blocktext(val)
#puts "format_blocktext:val";p val
      if vars
        vars.split(",").each{|var| 
          eval_SET(var.strip,val,filter)
        }
      else
        tex << val ####disabling: .force_encoding("utf-8")
      end
    end


    #######################################
    ## format helpers
    #######################################
    def format(which=:all)
      formats={
        :output => outputFormat,
        :blck => blockFormat,
        :parent => parentFormat,
        :default => defaultFormat,
        :current => currentFormat
      }
      which==:all ? formats : formats[which] 
    end

    def outputFormat
      @fmtOutput
    end

    def defaultFormat
      (@defaultFmtContainer.to_s)[0...-1]
    end

    def currentFormat
      (@curFmtContainer.to_s)[0...-1]
    end

    def blockFormat
      @fmtContainer[0] ? (@fmtContainer[0].to_s)[0...-1] : nil
    end

    def parentFormat(level=1)
      @fmtContainer[level] ? (@fmtContainer[level].to_s)[0...-1] : nil
    end
    #########################################

    def do_blck(tex,blck,filter)
#begin puts "do_blck";p @curCmd;p blck; end #if @curCmd=="navigator"
      i=0 #blck[0]==:blck
      #New mode (071108): save and restore named block!
      curCmd,blckname=@curCmd,nil
      if blck[1].is_a? Array
          blckname=parse([blck[1]],filter).strip
      end
      if curCmd=="saved"
        ####################################################################
        ## TODO: all the stuff generated has to be saved!
        ## tex records all the generated content but what about the files!
        ## Maybe, keep tracks of all files generated! By default put it inside inside .dyn_out directory
        ## but also records which files have been generated in the saved mode!
        ####################################################################  
        #blckname=parse([blck[1]],filter).strip
        ##puts "blckname";p blckname
        return if blckname.empty?
        unless blck[2]
          #p Utils.dyndoc_raw_var_ls
          #p blckname
          if Utils.dyndoc_raw_var_ls.include? blckname
            tex += Utils.dyndoc_raw_var_content(blckname,self)
          end
        else
          ## fetch the result from the saved result if it exists or force regeneration at the command line!
          res=Utils.saved_content_get(blckname,self,true) #true here is very important since input user is checked first to know if content needs to be regenerated!
          #puts "direct:res";p res
          unless res
            res=parse([blck[2..-1].unshift(:blck)],filter)
            #puts "created:res";p res
            ## saved_contents_file does not not contain this block!
            Utils.saved_content_add_as_variable(blckname,res,@filename)
          end
          tex << res ## stop here!
        end
      else #curCmd=="blck"
        @blckDepth ||= []
        @blckDepth << curCmd
        #puts "blckDepth";p @blckDepth;p @@newBlcks.keys
        if !(cmdBlcks=@@newBlcks.keys & @blckDepth).empty?
          #puts "cmdBlcks";p cmdBlcks
          #puts "blckDepth";p @blckDepth
          #p blck
          @newBlckMode=true
          (["blckAnyTag"]+cmdBlcks).each do |cmd|
            #puts "cmd";p cmd.to_sym;p blck[0]
            if blck[0]==cmd.to_sym
              #puts "BEFORE COMPLETED_BLCK";p blckname;p blck
              blck=completed_newBlck(cmd,blckname,blck,filter) 
              #puts "AFTER COMPLETED_BLCK";p blck
            end
          end
          
        elsif blck[1].is_a? Array
  	      #blckname=parse([blck[1]],filter).strip
  	      to_end=!blckname.empty?
  	      if blck[2] and to_end
  	        mode,to_exec=:normal,nil
  	        if ["+",">","$"].include? blckname[0,1]
  	          mode,blckname = :append,blckname[1..-1].strip
  	        elsif ["^","<"].include? blckname[0,1]
  	          mode,blckname = :prepend,blckname[1..-1].strip    
  	        end
  	        to_exec,blckname=true,blckname[0...-1] if blckname[-1,1]=="!"
#Dyndoc.warn "to_exec",[to_exec,blckname]
  	        @savedBlocks[blckname]= ( mode==:normal ? blck[2..-1].unshift(:blck) : ( mode==:append ? @savedBlocks[blckname]+blck[2..-1] : (blck[2..-1]+@savedBlocks[blckname][1..-1]).unshift(:blck) ) )
  	        tex << parse([@savedBlocks[blckname]],filter) if to_exec
  	      elsif to_end
  #p @savedBlocks[blckname]
  #puts "blck #{blckname}"
  	        tex << parse([@savedBlocks[blckname]],filter) if @savedBlocks[blckname]
  	      end
  #p to_stop;p blck
  	      return if to_end
        end
        # normal (old) mode
        cond,cond_tag=true,true
        condArch=[]       
        #p blck if curCmd=="tabbar"
        if @@newBlcks.keys.include? @blckDepth[-1]
          @blckName ||= []
          tmp=blck[1][1].strip
          @blckName << (tmp.empty? ? `uuidgen`.strip : tmp)
          #puts "blckNAME";p @blckName
        end

        begin
          current_block_tag=blck[i+=1]
          #Dyndoc.warn "blck3",current_block_tag
          case current_block_tag
  	      when :"%"
  	        i,*b2=next_block(blck,i)
  	      when :"?"
  	        i,*b2=next_block(blck,i)
  	        if cond_tag
  	          filter.outType=":rb"
  #puts "do_block:?:b2"; p b2
  	          code=parse_args(b2[0],filter).strip
  #puts "do_block:?:code"; p code
  	          mode=code.downcase
  #puts "do_block:?:mode";p mode
  	          if ["!","else"].include? mode
  	            cond = !cond
  	          elsif ["*","all","end"].include? mode
  	            cond,condArch=true,[]
  	          elsif mode=~/^prev/
  	            nbPop=mode.scan(/ \d*$/)
  	            nbPop=(nbPop.empty? ? 1 : nbPop[0].to_i)
  	            nbPop.times{cond=condArch.pop}
  	          else
  	            mode,code=code[0,1],code[1..-1] if ["&","|"].include? code[0,1]
                #Dyndoc.warn ":?",[@rbEnvir[0],code]
                cond2=@rbEnvir[0].eval(code)
                ##Dyndoc.warn "cond2",[cond2,@rbEnvir[0]]
  	            condArch << cond
  	            if mode=="&"
  		            cond=  cond & cond2
  	            elsif mode=="|"
  		            cond=  cond |  cond2
  	            else
  		            cond=cond2
  	            end
  	          end
  	          filter.outType=nil
  	        end
  #puts "cond in block #{code}=";p cond
  	      when :tag,:"??"
  ## Dyndoc.warn "tag:blck",blck         
  	        i,*b2=next_block(blck,i)
  ## Dyndoc.warn "tag:b2",b2
  	        code=parse(b2,filter).strip.downcase
  ## Dyndoc.warn "tag",code
  	        if ["!","else"].include? code
  	          cond_tag = !cond_tag
  	        elsif ["*","all","end"].include? code
  	          cond_tag=true
  	        else
  	          mode=nil
  	          mode,code=code[0,1],code[1..-1] if ["&","|","-"].include? code[0,1]
  ## Dyndoc.warn "mode and code",[mode,code]
  	          tags=TagManager.make_tags(code)
  ## Dyndoc.warn "tags, @tags",[tags,@tags]
  	    
  	          cond2_tag=TagManager.tags_ok?(tags,@tags)
  #puts "mode, cond_tag et cond2_tag";p mode; p cond_tag;p cond2_tag
  	          if mode=="&"
  #puts "tags, @tags";p tags;p @tags
  #puts "mode, cond_tag et cond2_tag";p mode; p cond_tag;p cond2_tag; p cond_tag.class;p cond2_tag.class;p cond_tag and  cond2_tag
  #RMK: a=0 and nil => a=0 because a stays to be a FixNum.
  		          cond_tag=  (cond_tag and  cond2_tag ? 0 : nil)
  #puts "INTER cond_tag->";p cond_tag
  	          elsif mode=="|"
  		          cond_tag =  (cond_tag or  cond2_tag ? 0 : nil)
  	          elsif mode=="-"
  		          cond_tag =  !cond2_tag
  	          else
  		          cond_tag = cond2_tag
  	          end
  #puts "FINAL cond_tag->";p cond_tag
  	        end
  #puts "cond_tag in block #{code}=";p cond_tag
          when :do,:<
            i,*b2=next_block(blck,i)
            parse(b2,filter) if cond_tag and cond
          when :"r<",:"rb<",:"R<",:"m<",:"M<",:"jl<"
            # if current_block_tag==:"jl<"
            #   ##p "iciiiii"
            # end
            newblck=blck[i]
  #puts "newblock";p newblck;p blck
            i,*b2=next_block(blck,i)
  #p b2 
  	          code=b2[0][1..-1]
##p code
              #need to be cleaned with no bracket at the beginning and the end of the block!
              clean_block_without_bracket(code)
  	          if cond_tag and cond
                b2=[code.unshift(newblck)]
    ##puts "r<;rb<";p b2
                filter.outType=":"+(blck[i].to_s)[0...-1]
                #p filter.outType
                parse(b2,filter)
                filter.outType=nil
        	    end
      	  when :"=" #equivalent of :var but DO NOT USE :var
      	    i,*b2=next_block(blck,i)
      	    if cond_tag and cond
      #puts "=:b2";p b2
      	      b=make_var_block(b2.unshift(:var),filter)
      #puts "=:b";p b  
      	      eval_VARS(b,filter)
      	    end
          when :"-"
            i,*b2=next_block(blck,i)
      	    if cond_tag and cond
      #puts "-:b2"
              parse(b2,filter).strip.split(",").each{|key| @vars.remove(key)}
      	    end
      	  when :+
      	    i,*b2=next_block(blck,i)
      	    if cond_tag and cond
      	      var,pos=b2[0][1].split(",")
      #p var;p pos
      	      pos = -1 unless pos
      	      pos=pos.to_i
      	      var=filter.apply(var)
      	      varObj=@vars.extract_raw(var)
      #puts "var:#{var}";p varObj
      	      if varObj
      		      if varObj.is_a? Array
      		        pos=varObj.length+pos+1 if pos<0
      		        varNew=var+".#{pos}"
      		        #new element
      		        b2[0][1]="::ADDED_ELT"
      #puts "+:b2";p b2
      		        b=make_var_block(b2.unshift(:var),filter)
      #p b
      		        eval_VARS(b,filter)
      		        type=@vars.extract_raw("::ADDED_ELT").class
      		        res={:val=>[""]}
      		        res=[] if type==Array
      		        res={} if type==Hash
      		        varObj.insert(pos,res)
      #p varObj
      #p b2
      		        b2[1][1]=varNew
      		        b=make_var_block(b2,filter)
      #p b
      		        eval_VARS(b,filter)
      		      elsif varObj.is_a? Hash and varObj[:val]
      		        b2[0][1]="::ADDED_ELT"
      #puts "+:b2";p b2
      		        b=make_var_block(b2.unshift(:var),filter)
      #p b
      		        eval_VARS(b,filter)
      		        res=@vars.extract_raw("::ADDED_ELT")
      		        varObj[:val][0].insert(pos,res[:val][0])
      		      end
      #puts "varNew:#{var}";p @vars.extract_raw(var)
      	      end
      	    end
           when :out,:>,:">!" # :>! is in some sense equivalent of :set
                  i,*b2=next_block(blck,i)
      #puts "block >, cond_tag, cond";p cond_tag ;p cond
      	     if cond_tag and cond and !b2.empty?
      #puts "do_blck:out";p b2
      #p blck
                  vars,b2=get_named_blck(b2,filter)
#Dyndoc.warn "do_blck:out, >!",[vars,b2] if current_block_tag==:">!"
      #p b2
      #p current_block_tag
      #p current_block_tag==:">!"
                    
                    make_named_blck(tex,filter,vars,b2,current_block_tag==:">!") if b2
             end
            when :"_<"
              i,*b2=next_block(blck,i)
              val=parse(b2,filter).strip
              @defaultFmtContainer=(val+">").to_sym if ["","html","tex","txtl","ttm","md"].include? val
            when :"txtl>",:"ttm>",:"tex>",:"html>",:"_>",:"__>",:"md>"
                newblck=blck[i]
                @curFmtContainer=:"tex>" unless @curFmtContainer
                if newblck==:"__>"
                  newblck=@curFmtContainer #the previous one
                elsif newblck==:"_>"
                  newblck=(@defaultFmtContainer ? @defaultFmtContainer : @curFmtContainer) #the default one
                else
                  @curFmtContainer=nil #to redefine at the end
                end
                i,*b2=next_block(blck,i)  
                if cond_tag and cond and !b2.empty? #if b2 empty nothing to do!
                  @fmtContainer.unshift newblck
                  val=parse(b2,filter) 
                  if @fmtContainer[1] and @fmtContainer[1]==@fmtContainer[0] #no need to convert!
                    tex += val
                  else #convert
                    ## Dyndoc.warn "txtl formats",[@fmtContainer[0],@fmtOutput,@fmtContainer[1]]
                    tex += Dyndoc::Converter.convert(val,@fmtContainer[0],@fmtOutput,@fmtContainer[1]) #last parameter: true means to protect
                  end
                  @curFmtContainer=@fmtContainer[0] unless @curFmtContainer
                  @fmtContainer.shift
                end

            when :"r>",:"rb>",:"R>",:"m>",:"M>",:"jl>"
                  newblck=blck[i]
                  i,*b2=next_block(blck,i) 
      #puts "RB>";p b2;p i;p blck
      	        if cond_tag and cond and !b2.empty? #if b2 empty nothing to do!
                  vars,b2=get_named_blck(b2,filter)
                  if b2
                    b2=[b2.unshift(newblck)]
                    filter.outType=":"+(blck[i].to_s)[0...-1]
                    make_named_blck(tex,filter,vars,b2)
                    filter.outType=nil
                  end
      	         end
      	  when :"r>>",:"R>>",:rout,:rverb
      	    newblck=blck[i]
                  i,*b2=next_block(blck,i) 
      	    if cond_tag and cond
                  vars,b2=get_named_blck(b2,filter)
                  if b2
                    b2=[b2.unshift(newblck)]
                    filter.outType=":r" #+(blck[i].to_s)[0...-1]
# #=begin
#       	      val=parse(b2,filter)
#       #puts "make_named_blck:val";p val
#       	      val=Utils.format_blocktext(val)
#       #puts "format_blocktext:val";p val
#       	      if vars
#       		vars.split(",").each{|var| 
#       		eval_SET(var.strip,val,filter)
#       	      }
#       	      else
#       		tex << val
#       	      end
# #=end
                    make_named_blck(tex,filter,vars,b2)
                    filter.outType=nil
                  end
      	    end
          when :"jl>>",:jlverb,:"rb>>",:rbverb
            newblck=blck[i]
                  i,*b2=next_block(blck,i) 
            if cond_tag and cond
                  vars,b2=get_named_blck(b2,filter)
                  if b2
                    b2=[b2.unshift(newblck)]
                    filter.outType=newblck.to_s[0,2].to_sym  #":jl" #+(blck[i].to_s)[0...-1]
# #=begin
#               val=parse(b2,filter)
#       #puts "make_named_blck:val";p val
#               val=Utils.format_blocktext(val)
#       #puts "format_blocktext:val";p val
#               if vars
#           vars.split(",").each{|var| 
#           eval_SET(var.strip,val,filter)
#               }
#               else
#           tex << val
#               end
# #=end
                    make_named_blck(tex,filter,vars,b2)
                    filter.outType=nil
                  end
            end
                when :>>
                  i,*b2=next_block(blck,i)
      	    if cond_tag and cond
                  file,b2=get_named_blck(b2,filter)
                  if b2 and file
                    mode=:save
                    case file[-1,1]
                    when "?"
                      mode=:exist
                      file=file[0...-1]
                    when "!"
                      mode=:nothing
                      file=file[0...-1]
                    end
                    mode=(File.exist?(file) ? :nothing : :save ) if mode==:exist
                    tex2=parse(b2,filter)
      	            tex2==Utils.format_blocktext(tex2)
                    if mode==:save
                      File.open(file,"w") do |f|
                        f << tex2
                      end
                    end
      	    end
                  end
                when :nl,:"\\n"
                  i,*b2=next_block(blck,i)
      	    if cond_tag and cond
                  tex << "\n" << parse(b2,filter)
      #puts "nl";p tex
      	    end
                when :yield #only inside a {#def] block!
                  i,*b2=next_block(blck,i)
      	    if cond_tag and cond
      	    codename=parse(b2,filter).strip
      #p codename
      #p @def_blck
                  make_yield(tex,codename,filter)
      	    end
      	  when :<< #input without variable entries
      	    i,*b2=next_block(blck,i)
      	    if cond_tag and cond
      #p b2
              var,b2=get_named_blck(b2,filter)
              #p var;p b2
      	      tmpl=parse(b2,filter).strip
      #p tmpl
              val=eval_INPUT(tmpl,[],filter)
              if var
                eval_SET(var.strip,val,filter)
              else
      	       tex << val
              end
      	    end
          else
            i,*b2=next_block(blck,i)
            blckCmd=(current_block_tag.is_a? Symbol) ?  "do_blck_"+curCmd+"_"+current_block_tag.to_s : nil
            blckCmd=nil if blckCmd and !(methods.include? blckCmd)
            if cond_tag and cond and blckCmd
              #puts "blck command";p blckCmd;p b2
              #p blckName
              method(blckCmd).call(tex,b2,filter)
            end
          end
        end while i<blck.length-1
        @blckName.pop if @blckName and @@newBlcks.keys.include? @blckDepth[-1]
        @blckDepth.pop
        @newBlckMode=nil
      end

    end


    def do_format(tex,blck,filter)
      i=0
      i,*b2=next_block(blck,i)
      format=parse(b2,filter).strip
      puts "format=#{format}"
      @fmtOutput=format
    end

    def do_main(tex,blck,filter)
      #OLD: @userTag.evalUserTags(tex,b[1],filter)
      #NEW: simply apply the filter on the text
      #b[1]="" unless b[1]
#Dyndoc.warn "do_main",blck[1]
      res=filter.apply(blck[1])
#Dyndoc.warn "do_main:res",res
      unless res.scan(/^__RAW__/).empty?
        res=Utils.protect_format_blocktext(res)
      else
	     res=Utils.format_blocktext(res)
      end
#Dyndoc.warn "do_main:res2"+res
      tex << res
      #Dyndoc.warn "ici"
      #TODO: maybe propose a language like textile to be converted in any format
    end

# #=begin
#     def do_TXT(tex,b,i,splitter,filter)
#       out = eval_TXT(b,filter)
# #p "OUT";p out
#       return unless out
#       tex << out << "\n" unless @echo<0
#     end
# #=end

    def make_var_block(blck,filter,dict=nil)
      b,i,go=[],-1,true
      cpt=0
#p blck
      begin
#p blck[i+1]
        case blck[i+=1]
        when :var, :","
#p blck[i]
          i,*b2=next_block(blck,i)
#puts "make_var";p i;p b2
#deal with
          unless b2.empty?
            name=nil
            if b2[0][0]==:named
              b2=b2[0]
              if b2[0]==:named
                b2 << [:main,""] unless b2[2]
                var=b2[2..-1]
                name=filter.apply(b2[1])
#puts "make_var_block:name";p name
#p dict
                if dict and (name2=dict.find{|v| v=~/^#{name}/})
                  name=name2
                  dict.delete(name)
                end
                b2=var
              end
            end
            
          end
#p name
#p b2
#p dict
	  # DO NOT remove lstrip! Otherwise, there is an error of compilation in test/V3/testECO2.dyn! => README.250808: OK now! The explanation was that is was needed only by @varscan (solved now)! The __STR__ escape the first and last whitespaces 
#p b2
          b2=parse(b2,filter) #.lstrip #.split("\n")
#puts "name";p name
#puts "b2222";p b2

	        sep=(dict ? "__ELTS__" : "\n" )
          #OLD: unless b2.empty? or b2=~/^:?:[#{FilterManager.letters}]*(?:\[(.*)\])?\s*=?(?:=>|,)/
	        unless b2=~ /^:?:[#{FilterManager.letters}]*(?:\[(.*)\])?\s*=?(?:=>|,)/
#puts "ICCIII";p b2
            name=(dict ? dict.shift : "var#{cpt+=1}" ) unless name
            if name
#puts "name0";p name
#p name[0,1]==":"
#puts "name";p name
	            modif,affect="","=>"
	            if name[-1,1]=="?"
		            name=name[0...-1]
		            if name[-1,1]=="!"
		              name=name[0...-1]
#p filter.envir.local
		              keys2=Envir.to_keys((name[0,1]=="." ? "self"+name : name)+"-USER-" )
#p keys2
		              env=Envir.elt_defined?(filter.envir.local,keys2)
#p env
		              if env=Envir.elt_defined?(filter.envir.local,keys2)
		                env[keys2[-1][0..-7]]=env[keys2[-1]]
		                env.delete(keys2[-1])
		                modif=nil
		                b2=nil
		              end
#p env
#p filter.envir.extract(name)
		            else
		              modif="?"
		            end
	            end
	            if modif
		            if name[-1,1]=="+"
		              name=name[0...-1]
		              modif+="+"
		            end
		            if name[-1,1]=="!"
#p "!!!!";p name
		              name=name[0...-1]
		              affect="==>"
		            end
		            name=":"+name unless name[0,1]==":"
		            affect="["+modif+"] "+affect unless modif.empty?  
#p b2.strip
		            if (arr=@varscan.build_vars(b2.strip)) #the stuff for parsing  array
#puts "arr";p arr
#p b2
		              b2=arr.map{|k,v|
		                name+"."+k+affect+Utils.protect_blocktext(v) 
		              }.join(sep)
                  ## add the order!
                  ## ONLY for list not array!
                  #b2+=sep+name+"._order_"+affect+Utils.protect_blocktext(arr.map{|k,v| k}.join(","))
                  #p b2
		            else
#puts "named";p b2
		              b2=name+affect+Utils.protect_blocktext(b2) #see README.250808!
		            end
#p b2
	            end
	          else
#puts "b2";p b2
	            b2=Utils.protect_blocktext(b2) #see README.250808!
#p b2
            end
          end
#puts "b2:#{name}";p b2
#p b2.split(sep)
          b += b2.split(sep) if b2
#puts "b";p b
        end
      end while i<blck.length-1
#puts "make_var_block";p b 
     return b
    end

    def do_var(tex,blck,filter)
#p blck
      b=make_var_block(blck,filter)
#puts "do_var:b";p b
#puts "do_var:filter.local";p filter.envir.local
      eval_VARS(b,filter)
    end
  
    def do_set(tex,blck,filter)
      i,*b2=next_block(blck,1)
#puts "set";p blck[1]
#p b2
#p parse_args(blck[1],filter)
      eval_SET(parse_args(blck[1],filter),parse(b2,filter),filter) #,true)
    end

    def do_hide(tex,blck,filter)
      ## nothing to do!!!
    end

    def do_txt(tex,blck,filter)
#p blck
      code=blck[1].dup
#puts "do_txt:code";p code
##p @curCmd

      ## to name some code block!
      #name=""
      ##JUST IN CASE, OLD: if code=~ /^\s*([\w\.\-_:]*)\s*\[(.*)\]\s*$/m #multiline!
      if code=~ /^\s*([\w\.\-_:]+)\s*\[(.*)\]\s*$/m #multiline!
        name,code=$1.strip,$2
        ##code="["+code+"]" if name.empty?
      end
      #puts "do_txt:name,code";p [name,code]
      ##
      @unprotected_txt=code
      @protected_txt=Utils.protect_txt_block(code)
#puts "do_txt:@protected_code";p @protected_code
#puts "do_txt2:code";p name;p code
      res = (@curCmd=="txt" ? code : @protected_txt )
      #puts "res";p res
      if name #unless name.empty?
#Dyndoc.warn "txt:name",[name,code]
        ## the following is only applied when @curCmd==">" or maybe ">>"
        filter.envir[name]=[code]
        outType=nil
        outType=filter.outType+"=" if filter.outType
        tex << filter.convert(name+"!",outType) if @curCmd==">"  #useful for templating as in Table.dyn 
      else
#Dyndoc.warn  "res",res
        tex << res
      end
    end

    def do_verb(tex,blck,filter)
      i=0
      i,*b2=next_block(blck,i)
      code=parse(b2,filter)
      Utils.escape!(code,[["{","__OPEN__"],["}","__CLOSE__"]])
      tex += Dyndoc::VERB[@cfg[:format_doc]][:begin] + "\n"
      tex += code.strip + "\n"
      tex += Dyndoc::VERB[@cfg[:format_doc]][:end] + "\n"
    end

    def do_eval(tex,blck,filter)
      i=0
#puts "do_eval";p blck
#puts '#{code}';p @vars["code"]
      i,*b2=next_block(blck,i)
      code=parse(b2,filter)
#puts "do_eval: code";p code
      Utils.escape_delim!(code)
#puts "do_eval2: code";p code
      mode=[]
      while code=~/^(test|pre|last|raw)\|.*/
        code = code[($1.length+1)..-1]
        mode << $1.to_sym
      end
      code=Dyndoc::Utils.dyndoc_raw_text(code) if mode.include? :test
      #puts "do_eval:mode";p mode;p code
      #PUT THE FOLLOWING IN THE DOCUMENTATION: 
      #puts "WARNING: {#dyn] accept :last and :raw in this order!" unless (mode - [:last,:raw]).empty?
      if mode.include? :pre
	      tex2=prepare_output(code) 
#puts "TOTO";p output_pre_model;p @pre_model
#puts "do_eval:PRE tex2";p tex2
      else
	      code="{#document][#main]"+code+"[#}"
#puts "do_eval:code";p code
	      tex2=parse(code,filter)
      end
      Utils.dyndoc_raw_text!(tex2) if mode.include? :last
#puts  "do_eval:tex2";p tex2
      tex2=Utils.dyndoc_raw_text_add(tex2) if mode.include? :raw
      tex += tex2
      if i<blck.length-1 and blck[i+=1]==:to
        i,*b2=next_block(blck,i)
        file=parse(b2,filter)
        unless file.empty?
          File.open(file,"w") do |f|
            f << tex2
          end
        end
      end
    end

    def do_ifndef(tex,blck,filter)
      i=0
      i,*b2=next_block(blck,i)
      file=parse(b2,filter).strip
#p file
      if File.exist?(file)
        tex += File.read(file)
      elsif blck[i+=1]==:<<
#p blck[(i+1)..-1]
        tex2=parse(blck[(i+1)..-1],filter)
#p tex2
        file=file[1..-1] if file[0,1]=="!"
        File.open(file,"w") do |f|
          f << tex2
        end
        tex += tex2
      end
    end

    def do_input(tex,blck,filter)
      tmpl=parse_args(blck[1],filter)
#p tmpl
      b=make_var_block(blck[2..-1].unshift(:var),filter)
#puts "do_input:b";p b
      tex += eval_INPUT(tmpl,b,filter)
    end
 
    def do_require(tex,blck,filter)   
      ## just load and parse : read some FUNCs and EXPORT some variables
      ## in the header
#p blck
#p parse_args(blck,filter)
      tmpl=parse_args(blck,filter).strip.split("\n")
#Dyndoc.warn "require",tmpl
      eval_LOAD(tmpl,filter)
    end
 
    def do_func(tex,blck,filter)
      call=parse_args(blck[1],filter)
      code=blck[2..-1]
#p "code func";p code
      eval_func(call,code)
    end

    def make_def(blck,filter)
      call=parse_args(blck[1],filter)
      code,arg,var,rbEnvir=nil,[],[:var],nil
      i=1
      begin 
        case blck[i+=1]
          when :binding
            i,*b2=next_block(blck,i)
            rbEnvir=b2[0][1].strip
          when :do,:<,:out,:>,:"r<",:"rb<",:"r>",:"R>",:"R<",:"r>>",:rverb,:"rb>>",:rbverb,:"jl>>",:jlverb,:"rb>",:"?",:tag,:"??",:yield,:>>,:"=",:"+",:<<,:"txtl>",:"html>",:"tex>",:"_>"
            code = blck[i..-1].unshift(:blck)
          when :"," 
            i,*b2=next_block(blck,i)
#p blck;p b2
            #deal with 
            b2=b2[0]
            if b2[0]==:named
# #=begin
# if false
# #Old one!
# #puts "b2";p b2
#               b2 << [:main,""] unless b2[2]
#               arg << b2[1]
#               var0=b2[2..-1]
#               var0[0][1]= ":"+b2[1]+"[?]=>" + var0[0][1]
# 	      var << :"," unless var.length==1
# #p var0
# 	      var += var0
# #next: New one 
# else
# #=end
#puts "b2";p b2
	      # 151108: Adding "!" at the end of the parameter name disables the default ability. This is completed with 
	      arg << (b2[1][-1,1]=="!" ? b2[1][0...-1]+"-USER-" : b2[1]) 
#p arg
	      b2[1]+="?"
	      b2 << [:main,""] unless b2[2]      
#p b2
              var << :"," unless var.length==1
              var << b2
#end 
	    elsif b2[0]==:main
#puts "make_def";p call
	      parse([b2],filter).split(",").map{|v| v.strip}.each{|v|
		var << :"," unless var.length==1
		var << [:named, v+"?" , [:main, ""]]
		arg << v
	      }
#p var
	      #var << b2
            end
          else #just after the arg is a comment and not dealt 
            i,*b2=next_block(blck,i)
        end
      end while i<blck.length-1 and !code
      #if no block code is provided (possible for method) nothing to do is represented by the following code!
      code=[:blck, :<]  unless code
      code=[code]
#puts "var";p var
      code.unshift(var) unless var.length==1
#puts "code def #{call}";p code
      call+= ((call.include? "|") ? "," : "|")+arg.join(",") unless arg.empty?
      return [call,code,rbEnvir]
    end

    def do_def(tex,blck,filter)
      call,code,rbEnvir=make_def(blck,filter)
#puts "do_def";p call;p code;p rbEnvir
      eval_func(call,code,rbEnvir)
    end

    def do_meth(tex,blck,filter)
#puts "do_meth";p blck
      call,code=make_def(blck,filter)
#puts "do_meth";p call;p code
      eval_meth(call,code)
    end

    def do_new(tex,blck,filter)
      #first declaration of the object
#puts "do_new";p blck
      var=parse_args(blck[1],filter).strip
      var = var[1..-1] if var[0,1]==":"
      i=2
      if blck[i]==:of
        i,*b2=next_block(blck,2)
        klass=parse(b2,filter).split(",").map{|e| e.strip}.join(",")
      else
        return
      end
      i+=1
      inR=@rEnvir[0]
      if blck[i]==:in
        i,*b2=next_block(blck,i)
#p b2
#p filter.envir.local["self"]
        inR=parse(b2,filter).strip
#p inR
        inR,parentR=inR.split("<").map{|e| e.strip}
        parentR=@rEnvir[0] unless parentR or  RServer.exist?(parentR)
#p parentR 
        RServer.new_envir(inR,parentR) unless RServer.exist?(inR)
        i+=1
      end
#puts "do_new:var,klass";p var;p klass
# =begin
#       b2=blck[4..-1].map{|e| 
#         if e.is_a? Array and e[0]==:named
#           e[1]=var+"."+e[1]
#         end
#         e
#       }
# =end
      b2=[[:named,var+".Class",[:main,klass]]]
      b2+=[:",",[:named,var+".Renvir",[:main,inR]]]
#puts "do_new:b2";p b2
      b=make_var_block(b2.unshift(:var),filter)
#puts "do_new:var";p b
      eval_VARS(b,filter)
#puts "do_new:eval_VARS";p filter.envir.local
      # and then call of the initialize method here called new.(Class)
# =begin
#       call="new"
#       bCall=get_method(call,get_klass(klass))
# p call
# =end
      b2=[] << :call<< [:args,[:main,"new"]] << [:named,"self",[:main,var]]
#p blck[4..-1]
      b2 += blck[i..-1]
#puts "do_new:new b2";p b2
      tex += parse([b2],filter)
      #tex << eval_CALL("new",b,filter)
    end

    def do_super(tex,blck,filter)
      #first declaration of the object
      var=parse_args(blck[1],filter).strip
      i=2
      parent=1
      if blck[i]==:parent
        i,*b2=next_block(blck,2)
        parent=parse(b2,filter).to_i
        parent=1 if parent==0
        i+=1
      end
      #find next class!
      super_meth=get_super_method(parent)
#p super_meth
      return "" unless super_meth
      #build the updtaed block
      b2=[] << :call<< [:args,[:main,super_meth]] << [:named,"self",[:main,var]]
      b2+=blck[i..-1]
#puts "super b2";p b2
      tex += parse([b2],filter)
      #tex << eval_CALL("new",b,filter)
    end

    def make_call(blck,filter)
      code,codename,var={"default"=>[:blck]},"default",[]
      i=-1
      begin 
        case blck[i+=1]
          when :blck
            #todo: change codename with the arg of blck
            i,*b2=next_block(blck,i)
            codename=parse(b2,filter).strip
            code[codename]=[:blck]
          when :do,:<,:out,:>,:"r<",:"rb<",:"r>",:"rb>",:nl,:"\n",:>>,:"?",:tag,:"??",:"=",:"+",:<<,:"%" #NO :yield because of infinite loops 
            code[codename] << blck[i]
            i,*b2=next_block(blck,i)
            code[codename] += b2
          when :var,:"," 
            var << blck[i]
            i,*b2=next_block(blck,i)
#puts "var et ,";p b2
            var += b2
	  else
	    var << :","
	    res=[:named,blck[i].to_s]
	    i,*b2=next_block(blck,i)
	    res += b2
	    var << res
#p var
        end
      end while i<blck.length-1
      code.each_key{|k| code.delete(k) if code[k].length==1 }
      return [var,code]
    end
 
    def do_call(tex,blck,filter)
#puts "do_call";p blck
      call=parse_args(blck[1],filter)
#puts "do_call";p call
#p args
      #this corrects a bad behavior of the scanner when the call directive is called directly.
      if blck[2]==:","
	var_block= blck[3..-1].unshift(:var)
      else
	var_block=blck[2..-1].unshift(:var)
      end
#puts "var_block";p var_block
      var,code=make_call(var_block,filter)
#puts "VAR"
#p code
#puts "do_call:var";p var

#p var
# #=begin
#       if @meths.include? call
#         @meth_var=(var[3..-1] ? var[0,1]+var[3..-1] : nil)
#         var=var[0..1]
#       end
# #=end
#puts "VAR2";p blck[2..-1].unshift(:var)
#puts "var block (AV)";p var

      #19/10/08: this complete the method name if necessary in order to provide args! Now, meth may be used with partial argument completed in the R spirit! 
      call4args,vars4args=call.dup,[]
      isMeth=CallFilter.isMeth?(call)
##puts "#{call} isMeth => #{isMeth}!!!"
      if isMeth
#puts "meth:call=#{call}"
	      obj=parse((var[1][0]==:named ? var[1][2..-1] : [var[1]] ),filter)
#puts "obj=#{obj}"
	      if @vars.extract(obj) and @vars.extract(obj).respond_to? "keys"
#puts "extract obj";p @vars.extract(obj).keys
	        vars4args=(@vars.extract(obj).keys.select{|e| e.is_a? String} - ["Renvir","ObjectName","Class"]).map{|e| "."+e}
	  #obj=parse([blck[2]],filter)
#p @vars[obj+".Class"]
	        get_method(call4args,@vars[obj+".Class"].split(",")) if @vars[obj+".Class"]
	        #=> call4args is modified inside get_method!!!
	      end
      end

#puts "call4args=#{call4args}" 
#p @args[call4args]   
      args=(@args[call4args] ? @args[call4args].dup : nil)
      args+=vars4args if args
#puts "args";p args
#TODO: for method, args has to be initialized by finding the class of the object! Pb: how to know that it is a method => make a method in Call???
      b=(var.length==1 ? [] : make_var_block(var,filter,args)) 
#puts "var block (AP)";p b
      b,meth_args_b=CallFilter.argsMeth(call,b) 
#puts "call";p call
#p @calls[call]
#puts "var2 block";p b
#p meth_args_b

#puts "call:out";p eval_CALL(call,b,filter)
      tex += eval_CALL(call,b,filter,meth_args_b,code)
    end


    def make_style_meth(meth,klass,blck)
      b=[:meth, [:args, [:main, "#{name_style(meth)}.Style#{klass}"]]]
      b += [:","] if ((blck[0].is_a? Array) and ([:main,:named].include? blck[0][0]))
      b += blck
#p b
      return b
    end

    def make_style_new(klass,blck)
      b=[:new, [:args,blck[0]],:of, [:main, "Style#{klass}"]]+blck[1..-1]
#puts "make_style_new";p b
      return b
    end

    ## this allows us to consider independently the calls {#p] and {@p] for user-defined only methods!!!!
    def name_style(call)
      call=="new" ? call : "_style_"+call
    end

    def make_style_call(call,obj,blck)
      b=[:call, [:args, [:main, name_style(call)]], [:main, obj]]
      unless blck.empty? #call not of the form {@toto@}
      	b += [:","]
      	#if only a block is given without parameter => no comma! => THIS IS NOT POSSIBLE BECAUSE OF THE CODE ARGUMENT!
      #puts "make_style_call:blck";p blck
      	b += ((blck[0].is_a? Array) ? blck : [blck])
      end
#puts "make_style_call";p b
      b
    end

    def register_style_init
      @styles={:cmd=>{},:class=>{},:alias=>{}} unless @styles
    end

    def register_style_meth(klass,meth)
      register_style_init
      @styles[:class][klass]=[] unless @styles[:class][klass]
      @styles[:class][klass] << meth
      @styles[:class][klass].uniq!
    end

    def register_style_cmds(cmds,style,force=nil)
      ## register cmds
      register_style_init
      cmds.each{|cmd| 
        @styles[:cmd][cmd]=style if force or !@styles[:cmd][cmd]
      }
    end 

    def do_style(tex,blck,filter)
      call=parse_args(blck[1],filter)
#p call
      call=call.split(":")
#puts "style:call";p call
#p @styles
#p blck[2..-1]
      if call[0][0,1]=~/[A-Z]/
      	# style declaration
      	unless call[1]
      	  # instance of new object
      	  b=make_style_new(call[0],blck[2..-1])
      	  do_new(tex,b,filter)
      	  style=parse_args(b[1],filter)
      #p style
      	  register_style_cmds(@styles[:class][call[0]],style)
      	else
      	  case call[1]
      	  when "new"
      	    # constructor style method called instance is demanded
      	    register_style_init
      	    b=make_style_meth("new",call[0],blck[2..-1])
            #p b
      	    do_meth(tex,b,filter)
      	    b=make_style_new(call[0],[[:main,call[0][0,1].downcase+call[0][1..-1] ]]) #,:<])
            #p b
            #p filter.envir
      	    do_new(tex,b,filter)
            #p filter.envir
      	  else
            #puts "register style meth:#{call[1]}.#{call[0]}"
      	    # style cmd method
      	    b=make_style_meth(call[1],call[0],blck[2..-1])
      	    do_meth(tex,b,filter)
      	    # register a new meth for this new Style Class
      	    register_style_meth(call[0],call[1])
      	    register_style_cmds([call[1]],call[0][0,1].downcase+call[0][1..-1])
      	  end
      	end
      elsif call[0]=="style"
      	if call[1]=="cmds"
      	  style=blck[2][1].strip
      	  cmds=(blck[4] ? blck[4][1] : nil)
      	  cmds=cmds.split(",").map{|cmd| cmd.strip} if cmds
      	  if @vars[style+".Class"]
      	    klass=@vars[style+".Class"][5..-1]
      	    cmds=(cmds ? cmds & @styles[:class][klass] : @styles[:class][klass] )
      	    register_style_cmds(cmds,style,true)
      	  end
      	elsif call[1]=="alias" and @styles
      	    aliases=parse([blck[2]],filter).split(",")
      	    value=parse([blck[4]],filter)
      	    aliases.each{|a| 
      	      @styles[:alias][a]=value 
      	    }
      	end
      else
      	# cmd style call
      	no_obj=call.length==1
      	obj,cmds=(no_obj ? [nil]+call : call)
# =begin
#       	if obj and !@vars[obj+".Class"]
#       	  cmds.unshift(obj)
#       	  obj=nil
#       	end
# =end
      	#recursive alias replacement

      ##TODO: it seems that no call in new is possible!
      #p cmds
      #register_style_init
      #p @styles
      	while !(aliases=(cmds.split("|") & @styles[:alias].keys)).empty?
      	  aliases.each{|a| cmds=cmds.gsub(a,@styles[:alias][a])}
      	end
      #puts "cmds";p cmds
      	cmds=cmds.split("|")
      #puts "cmds2";p cmds
      #TODO: facility to define alias for style!?!?!
      	b=blck[2..-1]
      #p cmds
      	cmds.reverse.each{|cmd|
      	  obj=@styles[:cmd][cmd] if no_obj
      #p @filter.envir
      	  b=make_style_call(cmd,obj,b)
      #p b
      	}
      #puts "style:call";p b
      	do_call(tex,b,filter)
      end
    end

    def do_loop(tex,blck,filter)
      ## last executing !!!
      ## To think about environment!!!
      cond=true
#p blck
      while cond
        i=-1
        begin

          case blck[i+=1]
          when :loop
            i,*b2=next_block(blck,i)
            tex += parse(b2,filter)
          when :break
            cond=!eval_args(blck[i+=1],filter)
            i,*b2=next_block(blck,i)
            tex += parse(b2,filter) if cond
	  end
	end while cond and i<blck.length-1
      end
    end

    def do_document(tex,blck,filter)
      i=0
#puts "document:blck"
#p blck
      begin
      	var,mode="",""
      	to_parse=true
#p i;p blck[i+1]
        case blck[i+=1]
        when :main,:content
          var,mode=nil,:view
	      when :require
	        var,mode=nil,:load
        when :helpers
          var,mode,to_parse=nil,:helpers,true
	      when :class
	        var,mode="_DOCUMENTCLASS_",""
        when :optclass
          var,mode,to_parse=nil,:optclass,true
        when :preamble
	        var,mode="_PREAMBLE_","+"
	      when :postamble
	        var,mode="_POSTAMBLE_","+"
	      when :style
	        var,mode="_STYLEDOC_","+"
	      when :package
	        var,mode="_USEPACKAGE_","+"
	      when :title
	        var,mode="_TITLE_","+"
	      when :path
	        var,mode=nil,:path
	      when :first
#p blck[i+=1]
	        var,mode,to_parse=nil,:first,false
	      when :last
	        var,mode,to_parse=nil,:last,false
        when :texinputs
          var,mode,to_parse=nil,:texinputs,true
	      end
	      i,*b2=next_block(blck,i)
#p b2
        res=parse(b2,filter) if to_parse
#p var
#puts "res";p res
	      unless var
	        case mode
	        when :view
	          tex << res
	        when :load
	          #puts "document:require";p  res
	          eval_LOAD(res.strip.split("\n"),filter)
          when :helpers
            eval_LOAD_HELPERS(res.strip.split("\n"),filter) 
	        when :path
#puts "document:path";p res
	          unless res.strip.empty?
	            paths=res.strip.split("\n").map{|e| e.strip unless e.strip.empty?}.compact
#p paths
              @tmpl_cfg[:rootDoc]="" unless @tmpl_cfg[:rootDoc]
#Dyndoc.warn "rootDoc",@tmpl_cfg[:rootDoc]
	            rootpaths=@tmpl_cfg[:rootDoc].split(Dyndoc::PATH_SEP)
#Dyndoc.warn "rootpaths",rootpaths
	            newpaths=[]
	            paths.each{|e| 
		            #if File.exist?(e)
		            #  newpaths << e
		            #els
                if e[0,1]=="-" and File.exist?(e[1..-1])
		              rootpaths.delete(e[1..-1])
		            elsif (ind=e.to_i)<0
		              rootpaths.delete_at(-ind-1)
                else
                  newpaths << e
		            end
	            }
	            rootpaths=newpaths+rootpaths
#p rootpaths
	            @tmpl_cfg[:rootDoc]=rootpaths.join(Dyndoc::PATH_SEP)
              #puts "rootDoc!!!!";p $curDyn[:rootDoc]
	          end
	        when :first
	          $dyn_firstblock=[] unless $dyn_firstblock
	          $dyn_firstblock+=b2
 #puts "$dyn_firstblock#{i}";p $dyn_firstblock
	        when :last
	          $dyn_lastblock=[] unless $dyn_lastblock
	          $dyn_lastblock+=b2
	    #p $dyn_lastblock
          when :texinputs
            sep=(RUBY_PLATFORM=~/mingw32/ ? ";" : ":")
            ENV["TEXINPUTS"]="" unless ENV["TEXINPUTS"]
            ENV["TEXINPUTS"]+=sep+res.strip.split("\n").join(sep)
          when :optclass
            optclass=res.strip.split("\n").join(",").split(",").map { |e| "\""+e.strip+"\"" }.join(",")
            #puts "optclass";p optclass
            eval_RbCODE("_optclass_ << ["+optclass+"]",filter)
	        end
	      else
          res=res.strip if var=="_DOCUMENTCLASS_"
	        eval_GLOBALVAR(var,res,filter,mode)
	        eval_TEX_TITLE(filter) if  var=="_TITLE_" and @cfg[:format_doc]==:tex
	      end
      end while i<blck.length-1
    end

# =begin
#     ## PB! never stop whenever condition is true => ex: if false (not exec), elsif true (exec), elsif false (not exec), else (is then exec)
#     def do_if(tex,blck,filter)
#       i,cond=-1,true
# #p blck
#       begin
#         filter.outType=":rb"
#         case blck[i+=1]
#           when :if
# #puts "do_if:blck[i+1]";p blck[i+1]
#             cond=eval_args(blck[i+=1],filter)
#           when :unless
#             cond=!eval_args(blck[i+=1],filter)
#           when :elsif
#             cond= (!cond and eval_args(blck[i+=1],filter))
#             #p blck[i]
#             #p eval_args(blck[i],filter)
#             #p cond
#           when :else
#             cond= !cond
#         end 
#         filter.outType=nil
#         i,*b2=next_block(blck,i)
#         tex << parse(b2,filter) if cond
#       end while i<blck.length-1
# #puts "tex";p tex
#     end
# =end

    def do_if(tex,blck,filter)
      i,cond=-1,nil
#p blck
      begin
        filter.outType=":rb"
        case blck[i+=1]
          when :if, :elsif
#puts "do_if:blck[i+1]";p blck[i+1]
            cond=eval_args(blck[i+=1],filter)
          when :unless
            cond=!eval_args(blck[i+=1],filter)
          when :else
            cond= true
        end 
        filter.outType=nil
        i,*b2=next_block(blck,i)
        tex << parse(b2,filter) if cond
      end while !cond and i<blck.length-1
#puts "tex";p tex
    end


# #BIENTOT OBSOLETE!
#     def do_for(tex,blck,filter)
#       filter.outType=":rb"
#       code=""
#       # @forFilter is here to make available the dyn variables!
#       @cptRbCode,@rbCode,@texRbCode,@forFilter=-1,{},{},filter unless @rbCode
#       code += "if res; for " + parse_args(blck[1],filter).strip + " do\n"
#       cpt=(@cptRbCode+=1) #local value to delete later! 
# #p cpt
#       @rbCode[cpt]=[blck[2..-1].unshift(:blck)]
#       @texRbCode[cpt]=tex
#       code += "@texRbCode[#{cpt}] << parse(@rbCode[#{cpt}],@forFilter)\n"
#       code += "end;end\n"
# #p code
# #puts "titi";p filter.envir.local
# #p @rbCode[cpt]
# #Dyndoc.warn :for_code,[code.encoding,code,__ENCODING__]
#       @rbEnvir[0].eval(code)
#       @rbCode.delete(cpt)
# #p @rbCode
#       @texRbCode.delete(cpt)
#       filter.outType=nil
#     end
   
   

    def do_case(tex,blck,filter)
      #Dyndoc.warn "do_case",blck
      choices=parse_args(blck[1],filter).strip
#puts "choices";p choices
#p blck
      var="__elt_case__"
      tmp=choices.scan(/(^\w*):(.*)/)[0]
      var,choices=tmp[0].strip,tmp[1].strip if tmp
      choices=choices.split(",").map{|e| e.strip}
      choices.each{|choice|
        i=1
        todo,cond,all=true,false,false
        begin
          case blck[i+=1]
          when :when
#puts "when";p blck[i]
            c=parse_args(blck[i+=1],filter).strip.split(",").map{|e| e.strip}
#p "#{choice} in #{c.join(",")}"
            cond=(c.include? choice)
            all |= cond
          when :else
            cond=!all
          end
          i,*b2=next_block(blck,i)
          @vars[var]=choice
          tex << parse(b2,filter) if cond
#if cond
#  puts "tex in case";p tex
#end
        end while todo and i<blck.length-1 
      }
#puts "tex in case";p tex
    end

    def do_r(tex,blck,filter)
      newblck=blck[0]
#puts "do_r";p blck
      filter.outType=":r"
      i=0
      i,*b2=next_block(blck,i)
      code=parse(b2,filter)
      inR=nil
      if blck[i+=1]==:in
        i,*b2=next_block(blck,i)
        inR=parse(b2,filter).strip
        RServer.new_envir(inR,@rEnvir[0]) unless RServer.exist?(inR)
      end
      #p [:do_r,inR]
      @rEnvir.unshift(inR) if inR
#puts "do_r:code";p code;p eval_RCODE(code,filter,true,true) if newblck==:"r>"
      if newblck==:"r>"
        tex2=eval_RCODE(code,filter,:pretty=> true,:capture=> true)
        ## Dyndoc.warn "rrrrrrrrrrrrrrr: tex2", tex2
        tex += tex2
      else
	# pretty is put to false because prettyNum does not accept empty output or something like that!
        eval_RCODE(code,filter,:pretty=> false)
      end
      @rEnvir.shift if inR
      filter.outType=nil
    end

    def do_renv(tex,blck,filter)
      inR=parse_args(blck,filter).strip
#p inR
      mode=:ls
      case inR[-1,1]
      when "+"
        mode=:attach
        inR=inR[0...-1]
      when "-"
        mode=:detach
        inR=inR[0...-1]
      when "?"
        mode=:show
        inR=inR[0...-1]
      end
      unless [:detach,:ls].include? mode
#puts "#{inR} EXIST?";p RServer.exist?(inR);"print(ls(.GlobalEnv$.env4dyn))".to_R
        RServer.new_envir(inR,@rEnvir[0]) unless RServer.exist?(inR)
      end
      case mode
      when :ls
        unless inR.empty?
          begin
            inRTmp=eval(inR)
            inR=(inRTmp.is_a? Regexp) ? inRTmp : /#{inR}/
          rescue
            inR=/#{inR}/
          end
        end
        tex += ((inR.is_a? Regexp) ? @rEnvir.select{|rEnv| rEnv=~ inR} : @rEnvir ).join(",")
      when :attach
        @rEnvir.unshift(inR) unless inR.empty?
      when :detach
        if inR.empty?
          @rEnvir.shift
        else
          if w=@rEnvir.index(inR)
            @rEnvir.delete_at(w) 
          end
        end
      when :show
        tex += (inR.empty? ? @rEnvir[0] : (@rEnvir[0]==inR).to_s)
      end
    end

    def do_rverb(tex,blck,filter)
#      require 'pry'
#      binding.pry
      newblck=blck[0]
      filter.outType=":r"
      i=0
      i,*b2=next_block(blck,i)
#puts "rverb:b2";p b2
      code=parse(b2,filter)
      i+=1
      inR=nil
      if blck[i]==:in
        i,*b2=next_block(blck,i)
        inR=parse(b2,filter).strip
        RServer.new_envir(inR,@rEnvir[0]) unless RServer.exist?(inR)
        i+=1
      end
      mode=@cfg[:mode_doc]
      #p [mode,@fmt,@fmtOutput]
      mode=@fmtOutput.to_sym if @fmtOutput and ["html","tex","txtl","raw"].include? @fmtOutput
      mode=(@fmt and !@fmt.empty? ? @fmt.to_sym : :default) unless mode
      if blck[i]==:mode
        i,*b2=next_block(blck,i)
        mode=parse(b2,filter).strip.to_sym
      end
      mode=:default if  newblck==:rout #or newblck==:"r>>"
      @rEnvir.unshift(inR) if inR
      process_r(code)
#puts "rverb:rcode";p code
      res=RServer.echo_verb(code,@@interactive ? :raw : mode,@rEnvir[0], prompt: (@@interactive ? "R" : ""))
##Dyndoc.warn "rverb:after",@@interactive
      require "dyndoc/common/uv" if @@interactive
      ##Dyndoc.warn "rverb:after",res
      warn_level = $VERBOSE;$VERBOSE = nil
      ##Dyndoc.warn "rverb:after",res
      ##tex += (@@interactive ? Uv.parse(res.force_encoding("utf-8"), "xhtml", File.join(Uv.syntax_path,"r.syntax") , false, "solarized",false) : res.force_encoding("utf-8") )
      tex << (@@interactive ? Uv.parse(res, "xhtml", File.join(Uv.syntax_path,"r.syntax") , false, "solarized",false) : res)
      ##Dyndoc.warn "rverb:after",res
      $VERBOSE = warn_level
#Dyndoc.warn "rverb:result",res 
      @rEnvir.shift if inR
      filter.outType=nil
    end

    def do_rbverb(tex,blck,filter)
#      require 'pry'
#      binding.pry
      newblck=blck[0]
      filter.outType=":rb"
      i=0
      i,*b2=next_block(blck,i)
#puts "rverb:b2";p b2
      code=parse(b2,filter)
      i+=1
      
      mode=@cfg[:mode_doc]
      #p [mode,@fmt,@fmtOutput]
      mode=@fmtOutput.to_sym if @fmtOutput and ["html","tex","txtl","raw"].include? @fmtOutput
      mode=(@fmt and !@fmt.empty? ? @fmt.to_sym : :default) unless mode
      if blck[i]==:mode
        i,*b2=next_block(blck,i)
        mode=parse(b2,filter).strip.to_sym
      end
      
      process_rb(code)
      ## Dyndoc.warn "rverb:rcode";p code
      res=RbServer.echo_verb(code,@@interactive ? :raw : mode,@rbEnvir[0])
      ## Dyndoc.warn "rbverb:res",res
      require "dyndoc/common/uv" if @@interactive
      warn_level = $VERBOSE;$VERBOSE = nil
      tex += (@@interactive ? Uv.parse(res, "xhtml", File.join(Uv.syntax_path,"ruby.syntax") , false, "solarized",false) : res )
      $VERBOSE = warn_level
#puts "rverb:result";p res 
      
      filter.outType=nil
    end

    def do_jlverb(tex,blck,filter)
#      require 'pry'
#      binding.pry
      newblck=blck[0]
      filter.outType=":jl"
      i=0
      i,*b2=next_block(blck,i)
#puts "rverb:b2";p b2
      code=parse(b2,filter)
      i+=1
      
      mode=@cfg[:mode_doc]
      #p [mode,@fmt,@fmtOutput]
      mode=@fmtOutput.to_sym if @fmtOutput and ["html","tex","txtl","raw"].include? @fmtOutput
      mode=(@fmt and !@fmt.empty? ? @fmt.to_sym : :default) unless mode
      if blck[i]==:mode
        i,*b2=next_block(blck,i)
        mode=parse(b2,filter).strip.to_sym
      end
       
      process_jl(code)
#puts "rverb:rcode";p code
      res=JLServer.echo_verb(code,@@interactive ? :raw : mode)
      require "dyndoc/common/uv" if @@interactive
      warn_level = $VERBOSE;$VERBOSE = nil
      tex += (@@interactive ? Uv.parse(res, "xhtml", File.join(Uv.syntax_path,"julia.syntax") , false, "solarized",false) : res )
      $VERBOSE = warn_level
#puts "rverb:result";p res 
      
      filter.outType=nil
    end
 
    def dynBlock_in_doLangBlock?(blck)
      blck.map{|b| b.respond_to? "[]" and [:>,:<,:<<].include? b[0] }.any?
    end

    #attr_accessor :doLangBlock    

    def make_do_lang_blck(blck,id,lang=:rb)
      #p blck
      cptCode=-1
## Dyndoc.warn "make_do_lang_blck",blck
      blck2=blck.map{|b|
## Dyndoc.warn "b",b
        if b.respond_to? "[]" and [:>,:<,:<<].include? b[0]
          cptCode+=1
          @doLangBlock[id][:code][cptCode]=Utils.escape_delim!(b[1])
          codeLangBlock = "Dyndoc.curDyn.tmpl.eval"+ lang.to_s.capitalize+"Block(#{id.to_s},#{cptCode.to_s},:#{b[0].to_s},:#{lang})"

          @doLangBlockEnvs=[0] unless @doLangBlockEnvs #never empty?
          @doLangBlockEnvs << (doLangBlockEnv=@doLangBlockEnvs.max + 1)
          @doLangBlock[id][:env] << doLangBlockEnv
          
          ## NEW: Special treatment for R code because environment is different from GlobalEnv
          case lang
          when :R
            # first, get the environment
            codeLangBlock="{.GlobalEnv$.env4dyn$rbBlock#{doLangBlockEnv.to_s} <- environment();.rb(\""+codeLangBlock+"\");invisible()}"
            # use it to evaluate the dyn block with R stuff! (renv) 
            @doLangBlock[id][:code][cptCode]= "[#<]{#renv]rbBlock#{doLangBlockEnv.to_s}+[#}[#>]"+@doLangBlock[id][:code][cptCode]+"[#<]{#renv]rbBlock#{doLangBlockEnv.to_s}-[#}"
          when :jl
            # Nothing since no binding or environment in Julia
            # Toplevel used
            codeLangBlock="begin Ruby.run(\""+codeLangBlock+"\") end"
            @doLangBlock[id][:code][cptCode]= "[#>]"+@doLangBlock[id][:code][cptCode]
          when :rb
            ##DEBUG: codeRbBlock="begin $curDyn.tmpl.rbenvir_go_to(:rbBlock#{rbBlockEnv.to_s},binding);p \"rbBlock#{doBlockEnv.to_s}\";p \"rbCode=#{codeRbBlock}\";$result4BlockCode="+codeRbBlock+";$curDyn.tmpl.rbenvir_back_from(:rbBlock#{doLangBlockEnv.to_s});$result4BlockCode; end" 
            codeLangBlock="begin Dyndoc.curDyn.tmpl.rbenvir_go_to(:rbBlock#{doLangBlockEnv.to_s},binding);$result4BlockCode="+codeLangBlock+";Dyndoc.curDyn.tmpl.rbenvir_back_from(:rbBlock#{doLangBlockEnv.to_s});$result4BlockCode; end"    
          end
          case lang
          when :R 
            process_r(@doLangBlock[id][:code][cptCode])
          when :jl
            # TODO
            process_jl(@doLangBlock[id][:code][cptCode])
          when :rb
            @doLangBlock[id][:code][cptCode]=process_rb(@doLangBlock[id][:code][cptCode])
          end
          [:main,codeLangBlock]
        else
          b
        end
      }
## Dyndoc.warn  "cptRb",cptRb
## Dyndoc.warn "blck2",blck2
      blck2
    end

    def evalRbBlock(id,cpt,tag,lang=:rb)
## Dyndoc.warn "@doLangBlock[#{id.to_s}][:code][#{cpt.to_s}]",@doLangBlock[id][:code][cpt]#,@doLangBlock[id][:filter]
      ## this deals with the problem of newBlcks!
      ##puts "block_normal";p blckMode_normal?
      code=(blckMode_normal? ? @doLangBlock[id][:code][cpt] : "{#blckAnyTag]"+@doLangBlock[id][:code][cpt]+"[#blckAnyTag}" )
      #puts "code";p code
      @doLangBlock[id][:out]=parse(code,@doLangBlock[id][:filter])
      ##Dyndoc.warn "evalRbBlock:doLangBlock",[id,code,@doLangBlock[id][:out]] if tag == :>

      #########################################
      ## THIS IS FOR OLD
      ##@doLangBlock[id][:tex] << @doLangBlock[id][:out] if tag == :>
      ## THIS IS NEW
      print @doLangBlock[id][:out] if tag == :>
      ## 
      #Dyndoc.warn "EVALRBBLOCK: @doLangBlock[id][:out]",@doLangBlock[id][:out] if tag == :>
      #######################################

      if tag == :<<
        return ( lang==:R ? RServer.output(@doLangBlock[id][:out],@rEnvir[0],true) : eval(@doLangBlock[id][:out]) )
      else
        return @doLangBlock[id][:out]
      end  
    end

# =begin DO NOT REMOVE: OLD STUFF (just in case the experimental one fails!!!)
#     def do_rb(tex,blck,filter)
#       ##a new rbEnvir is added inside this function! For a while, every ruby code is to evaluate inside this envir till the end of function.
#       ## rbBlock stuff
# #p blck
# #puts "do_rb binding"; p binding; p local_variables
#       dynBlock=dynBlock_in_doLangBlock?(blck)
#       if dynBlock 
#         ##OLD:@filterRbBlock=filter
#         @doLangBlock=[] unless @doLangBlock
#         @doLangBlock << {:tex=>'',:code=>[],:out=>'',:filter=>filter,:env=>[]} #@filterRbBlock}
#         rbBlockId=@doLangBlock.length-1
#         #OLD:eval("rbBlock={:tex=>'',:code=>[],:out=>'',:filter=>@filterRbBlock}",@rbEnvir[0])
#       end
#       ## this is ruby code!
#       filter.outType=":rb"
# #puts "do_rb";p filter.envir.local
#       blck=make_do_lang_blck(blck,rbBlockId)
# #puts "do_rb";p blck
#       code = parse_args(blck,filter)
# #puts "rb code="+code
#       process_rb(code) if Utils.raw_code_to_process
# #puts "rb CODE="+code
#       res=eval_RbCODE(code,filter)
#       tex2=(dynBlock ? @doLangBlock[rbBlockId][:tex] : (blck[0]==:"rb>" ? res : ""))
#       #OLD:tex2=(dynBlock ? eval("rbBlock[:tex]",@rbEnvir[0]) : "")
# #puts "tex2";p tex2
#       tex << tex2
#       #tex << res if blck[0]==:"rb>" and !dynBlock #and tex2.empty? ##=> done above!
#       ## revert all the stuff
#       if dynBlock
#         @doLangBlockEnvs -= @doLangBlock[rbBlockId][:env] #first remove useless envRs
#         @doLangBlock.pop
#       end
#       filter.outType=nil
# #puts "SORTIE RB!"
# #p dynBlock; p blck;p tex2
#     end
# =end

#=begin NEW STUFF!!!
    def do_rb(tex,blck,filter)
      ##disabled: require 'stringio'
      @rbIO=[] unless @rbIO
      ##@rbIO << (blck[0]==:"rb>" ? StringIO.new : STDOUT)
      @rbIO << (blck[0]==:"rb>" ? STDOUT : STDOUT)
      $stdout=@rbIO[-1]

      ## Dyndoc.warn "blck",blck
      ## Dyndoc.warn "do_rb binding",binding,local_variables
      dynBlock=dynBlock_in_doLangBlock?(blck)
      if dynBlock 
        @doLangBlock=[] unless @doLangBlock
        @doLangBlock << {:tex=>'',:code=>[],:out=>'',:filter=>filter,:env=>[]} #@filterRbBlock}
        rbBlockId=@doLangBlock.length-1
      end
      ## this is ruby code!
      filter.outType=":rb"
      ## Dyndoc.warn "do_rb",filter.envir.local
      blck=make_do_lang_blck(blck,rbBlockId)
      ## Dyndoc.warn "do_rb",blck
      code = parse_args(blck,filter)
      ## Dyndoc.warn "rb code="+code
      ####disabled: process_rb(code) if Utils.raw_code_to_process
      ## Dyndoc.warn "rb CODE="+code
      res=eval_RbCODE(code,filter)

      if blck[0]==:"rb>"
        tex2=@rbIO.pop.string
#Dyndoc.warn "res",res
#Dyndoc.warn "RbRbRbRbRbRbRb:", (tex2.empty? ? res : tex2)
        tex += (tex2.empty? ? res : tex2)
      else
        @rbIO.pop
      end

      ## revert all the stuff
      if dynBlock
        @doLangBlockEnvs -= @doLangBlock[rbBlockId][:env] #first remove useless envRs
        @doLangBlock.pop
      end
      $stdout=@rbIO.empty? ? STDOUT : @rbIO[-1]
      
      filter.outType=nil
      ## Dyndoc.warn "SORTIE RB!",dynBlock,blck,tex2
    end
#=end


    def evalRBlock(id,cpt,tag,lang=:R)
      ## this deals with the problem of newBlcks!
      ## Dyndoc.warn "block_normal",blckMode_normal?
      code=(blckMode_normal? ? @doLangBlock[id][:code][cpt] : "{#blckAnyTag]"+@doLangBlock[id][:code][cpt]+"[#blckAnyTag}" )
      ## Dyndoc.warn "codeR",code
      @doLangBlock[id][:out]=parse(code,@doLangBlock[id][:filter])
      ## Dyndoc.warn "code2R", @doLangBlock[id][:out]
      if tag == :>
        outcode=@doLangBlock[id][:out].gsub(/\\/,'\\\\\\\\') #to be compatible with R
        outcode=outcode.gsub(/\'/,"\\\\\'")
        #Dyndoc.warn 
        outcode='cat(\''+outcode+'\')'
        #Dyndoc.warn "outcode",outcode
        outcode.to_R # CLEVER: directly redirect in R output that is then captured
      end
      if tag == :<<
        return ( lang==:R ? RServer.output(@doLangBlock[id][:out],@rEnvir[0],true) : eval(@doLangBlock[id][:out]) )
      else
        return @doLangBlock[id][:out]
      end  
    end


    def do_R(tex,blck,filter)
      ## rBlock stuff
      # Dyndoc.warn "do_R",blck
      dynBlock=dynBlock_in_doLangBlock?(blck)
      if dynBlock 
        @doLangBlock=[] unless @doLangBlock
        @doLangBlock << {:tex=>'',:code=>[],:out=>'',:filter=>filter,:env=>[]}
        rBlockId=@doLangBlock.length-1
      end
      ## this is R code!
      filter.outType=":r"
      ## Dyndoc.warn "do_R",filter.envir.local
      blck=make_do_lang_blck(blck,rBlockId,:R) #true at the end is for R!
      ## Dyndoc.warn "do_R",blck
      code = parse_args(blck,filter)
      ## Dyndoc.warn "R code="+code
      process_r(code)
      ## Dyndoc.warn "R CODE="+code

      if blck[0]==:"R>"
        ## Dyndoc.warn "R>",code
        tex2=eval_RCODE(code,filter,:blockR => true)
        ## Dyndoc.warn "RRRRRRRRRRRRRRRR: tex2",tex2
        tex += tex2 
      else
        # pretty is put to false because prettyNum does not accept empty output or something like that!
        eval_RCODE(code,filter,:pretty=> false)
      end
      ## revert all the stuff
      if dynBlock
        @doLangBlockEnvs -= @doLangBlock[rBlockId][:env] #first remove useless envRs
        @doLangBlock.pop
      end
      filter.outType=nil
      ## Dyndoc.warn "SORTIE R!",dynBlock,blck,tex2
    end

    def evalJlBlock(id,cpt,tag,lang=:jl)
      ## Dyndoc.warn "evalJlBlock!!!"
      ## this deals with the problem of newBlcks!
      ## Dyndoc.warn "block_normal",blckMode_normal?
      ## Dyndoc.warn "@doLangBlock",@doLangBlock
      code=(blckMode_normal? ? @doLangBlock[id][:code][cpt] : "{#blckAnyTag]"+@doLangBlock[id][:code][cpt]+"[#blckAnyTag}" )
      ## Dyndoc.warn "codeJL",code
      ## Dyndoc.warn "filter",@doLangBlock[id][:filter]
      @doLangBlock[id][:out]=parse(code,@doLangBlock[id][:filter])
      ## Dyndoc.warn "code2JL",@doLangBlock[id][:out]
      ## Dyndoc.warn tag
      if tag == :>
        outcode=@doLangBlock[id][:out] #.gsub(/\\/,'\\\\\\\\') #to be compatible with R
        outcode='print("'+outcode+'")'
        ## Dyndoc.warn "outcode",outcode
        Julia.exec outcode,:get=>nil # CLEVER: directly redirect in R output that is then captured
      end
      if tag == :<<
        return ( lang==:jl ? JLServer.eval(@doLangBlock[id][:out],@rEnvir[0],true) : eval(@doLangBlock[id][:out]) )
      else
        return @doLangBlock[id][:out]
      end  
    end

#     def do_jl(tex,blck,filter)
#       return unless $cfg_dyn[:langs].include? :jl
#       ## rbBlock stuff
#       dynBlock=dynBlock_in_doLangBlock?(blck)
#       if dynBlock 
#         @doLangBlock=[] unless @doLangBlock
#         @doLangBlock << {:tex=>'',:code=>[],:out=>'',:filter=>filter,:env=>[]}
#         jlBlockId=@doLangBlock.length-1
#       end
#       ## Dyndoc.warn "do_jl";p blck
#       filter.outType=":jl"
#       # i=0
#       # i,*b2=next_block(blck,i)
#       # code=parse(b2,filter)
#       blck=make_do_lang_blck(blck,jlBlockId,:jl)
#       ## Dyndoc.warn "do_jl",blck
#       code = parse_args(blck,filter)
#       ## Dyndoc.warn "DO_JL",code
#       ## Dyndoc.warn "@doLangBlock",@doLangBlock[0][:code] if @doLangBlock[0]
#       process_jl(code)
#       ## Dyndoc.warn "code_jl",code
#       if [:"jl>"].include? blck[0]
#         tex += JLServer.outputs(code,:block => true)
#       else
#         JLServer.eval(code)
#       end
#       ## revert all the stuff
#       if dynBlock
#         @doLangBlockEnvs -= @doLangBlock[jlBlockId][:env] #first remove useless envRs
#         @doLangBlock.pop
#       end
#       filter.outType=nil
#     end

#     def do_m(tex,blck,filter)
#       newblck=blck[0]
# # Dyndoc.warn "do_m";p blck
#       filter.outType=":m"
#       i=0
#       i,*b2=next_block(blck,i)
#       code=parse(b2,filter)
       
#       #p ["Mathematica",code]
#       code='TeXForm['+code+']' if blck[0]==:"M>"
#       tex2=Dyndoc::Converter.mathlink(code)
#       if [:"M>",:"m>"].include? blck[0]
#         tex += (blck[0]==:"M>" ? ('$'+tex2+'$').gsub("\\\\","\\") : tex2 )
#       end
#       filter.outType=nil
#     end

#     def do_tags(tex,blck,filter)
#       i=0
# #puts "do_tags"
# #p @tags
# #p blck.length
#       if blck.length==1
#         ##p @tags.map{|t| t.inspect}.join(",")
#         tex += @tags.map{|t| t.inspect}.join(",")
#         return
#       end
#       begin
#         case blck[i+=1]
#         when :when
#           tags=TagManager.make_tags(parse_args(blck[i+=1],filter).strip)
#         else
#           puts "ERROR! Only [#when] tag! ";p blck[i]
#         end 
# #p part_tag
#         i,*b2=next_block(blck,i)
#         # fparse if allowed!
#         if TagManager.tags_ok?(tags,@tags)
# #p b2
#           tex += parse(b2,filter)
#         end 
#       end while i<blck.length-1
#     end

#     def do_keys(tex,blck,filter)
#       arg=parse_args(blck[1],filter).strip
# #puts "do_keys: @keys";p @keys
#       #Register!      
#       if arg[0..8]=="register:" 
# #puts ">>>>>>>>> Keys->Register";p arg
# #puts "@keys:";p @keys
# 	      $dyn_keys={} unless $dyn_keys
# 	      unless $dyn_keys[:crit]
# 	        $dyn_keys[:crit]={:pre=>[],:user=>[]}
# 	        $dyn_keys[:index]=$dyn_keys[:crit][:user]
# 	        ## predefined
# 	        $dyn_keys[:crit][:pre]=["order","required"]
# 	        $dyn_keys["order"]={:type=>:order} 
# 	        $dyn_keys["required"]={:type=>:required}
# 	        ## user defined
# 	        $dyn_keys[:alias]=[] 
# 	        $dyn_keys[:current]=[] 
# 	        $dyn_keys[:begin]=[]
# 	        $dyn_keys[:end]=[]
# 	      end
# 	      arg[9..-1].split(":").each{|e| 
# 	        type=e.split("=").map{|e2| e2.strip}
# 	        res={:type=>type[1].to_sym}
# 	        crit,*aliases=type[0].split(",").map{|e2| e2.strip}
# 	        $dyn_keys[:index] << crit
# 	        $dyn_keys[crit]=res
# 	        #which criteria need some further treatments
# 	        $dyn_keys[:begin] << crit if [:section].include? res[:type]
# 	        $dyn_keys[:end] << crit if [:section].include? res[:type]
# 	        unless aliases.empty?
# 	          $dyn_keys[:alias]+=aliases
# 	          aliases.each{|e| $dyn_keys[e]=crit}
# 	        end
# 	      }
# 	      $dyn_keys[:index] << "order" << "required"
# #puts "$dyn_keys";p $dyn_keys
# #puts "Before: @keys:";p @keys
# #p @init_keys
# 	      @keys.merge!(KeysManager.make_keys(@init_keys)) if @init_keys
# #puts "After make_keys: @keys";p @keys #if @tmpl_cfg[:debug]
# #p @init_keys
#       #Set!
#       elsif arg[0..3]=="set:" 
# ##puts ">>>>>>>>> Keys->Set"
# 	      @init_keys=KeysManager.init_keys([arg[4..-1].strip])
# 	      @keys.merge!(KeysManager.make_keys(@init_keys))
#       #Require!
#       elsif arg[0..7]=="require:"
# ##puts ">>>>>>>>> Keys->Require"
# 	      $dyn_keys[:require]=":"+arg[8..-1]

#       #Select!
#       else
# #puts ">>>>>>>>> Keys->Select"
# 	      to_merge=(arg[0,1]=="+")
# 	      if $dyn_keys[:current].empty?
# 	        mode_keys=:init
# 	        $dyn_keys[:cpt]=0
# 	        $dyn_keys[:tex]={}
# 	        lock_parent=nil unless to_merge
# 	      else
# 	        mode_keys=:fetch
# 	        lock_parent=$dyn_keys[:current][-1] unless to_merge
# 	        $dyn_keys[:cpt]+=1
# 	      end
	
# #puts "mode_keys";p mode_keys
# #p arg
# 	      arg=arg[1..-1] if to_merge
# 	      lock=KeysManager.make(arg)
# 	      lock=KeysManager.var_names(lock)
# 	      KeysManager.simplify(lock) #simplify default value!
# 	      lock_keys_orig=lock.keys
# 	      if to_merge
# 	        KeysManager.merge(lock)
# 	      elsif lock_parent
# 	        KeysManager.merge(lock,lock_parent) 
# 	      end
# #p lock
# 	      KeysManager.make_title(lock)
# #p $dyn_keys[:title]
	
# #puts "do_keys:lock";p lock
# 	      # remember the last lock!
# 	      $dyn_keys[:lastlock]=lock
# 	      $dyn_keys[:current] << lock
# ##IMPORTANT: put here and not after the parsing otherwise cpt increases abnormally.
# 	      unless mode_keys==:init
# 	        tex += "__DYNKEYS#{$dyn_keys[:cpt]}__"
# 	      end
# 	      KeysManager.begin(lock_keys_orig,lock,@keys)
# 	      @lock=lock #to use inside dyndoc!
# 	      $dyn_keys[:tex][$dyn_keys[:cpt]] = {:lock=>lock,:content=>parse([blck[2..-1].unshift(:blck)],filter)}
# 	      if mode_keys==:init
# #puts "$dyn_keys[:tex]";p $dyn_keys[:tex]
# 	        texAry=keys_recurse($dyn_keys[:tex][0])
# #puts "texAry";p texAry
#           texAry=[texAry] unless texAry.is_a? Array
# 	        keys_print(tex,texAry)
# 	      end
# 	      KeysManager.end(lock_keys_orig,lock,@keys)
# 	      $dyn_keys[:current].pop
#       end
#     end

#     def keys_recurse(tex)
# #puts "keys_recurse: tex";p tex
#       texAry=tex[:content].split(/__DYNKEYS(\d+)__/,-1)
#       if texAry.length==1
# 	      tex
#       else
# 	      (0...texAry.length).map do |i|
# 	        if i%2==1
# 	          keys_recurse($dyn_keys[:tex][texAry[i].to_i])
# 	        else
# 	          {:lock=>tex[:lock],:content=>texAry[i]}
# 	        end
# 	      end
#       end
#     end

#     def keys_show(texAry)
#       puts "@keys";p @keys
#       texAry.each{|e|     
# 	      p e[:lock]
# 	      p e[:content]
#       }
#     end

#     def keys_select(texAry)
#       texAry.find_all{|e| 
# 	      KeysManager.unlocked?(e[:lock],@keys)
#       }
#     end

#     def keys_compare(e1,e2)
#       i,res=0,0
# #p @keys["order"]
# 	    while res ==0 and i<@keys["order"].length
# 	      a=@keys["order"][i]
# #puts "a";p a
# 	      res=a[:order]*(e1[:lock][a[:val]] <=> e2[:lock][a[:val]])
# 	      i+=1
# 	    end 
# 	    #because of pb of sort to deal with equality!
# 	    res=e1[:index]<=>e2[:index] if res==0
# 	    res
#     end

#     def keys_sort(texAry)
#       texAry.each_with_index{|e,i| e[:index]=i}
#       texAry.sort{|e1,e2|
# #p e1;p e2
# 	keys_compare(e1,e2)
#       }
#     end
    

#     def keys_print(tex,texAry) 
#       #keys_show(texAry.flatten) if @tmpl_cfg[:debug]
#       texAry=keys_select(texAry.flatten)
#       keys_show(texAry) if @tmpl_cfg[:debug]
#       texAry=keys_sort(texAry) if @keys["order"]
#       #puts "SORTED"
#       #keys_show(texAry)
#       texAry.each{|e| tex += e[:content]}
#     end

    def do_opt(tex,blck,filter)
#p blck
#p parse(blck[1..-1],filter)
#p parse(blck[1..-1],filter).split(",").map{|e| e.strip}
#p @tags
      taglist=parse(blck[1..-1],filter).strip
  
      taglist.split(",").map{|e| e.strip}.each{|tag|
        if tag[0,1]=="-"
          @tags.delete(TagManager.init_input_tag(tag[1..-1]))
        else
  	     tag=tag[1..-1] if tag[0,1]=="+"
  	     @tags << TagManager.init_input_tag(tag) 
        end
      }
#puts "ici";p @tags
    end

    def make_yield(tex,codename,filter)
      if @def_blck[-1] and @def_blck[-1].keys.include? codename
	#codename="default" unless @def_blck[-1].keys.include? codename
#p codename
#p @def_blck[-1][codename]
#p parse([@def_blck[-1][codename]],filter) if @def_blck[-1][codename]
        tex += parse([@def_blck[-1][codename]],filter) if @def_blck[-1][codename]
#p filter.envir.local["self"]
       end 
    end

    def do_get(tex,blck,filter)
      blckname=filter.apply(blck[1][1])
      codename=filter.apply(blck[3][1])
      if @def_blck[-1] and @def_blck[-1].keys.include? codename
	       @savedBlocks[blckname]=@def_blck[-1][codename]
#puts "do_get";p @savedBlocks[blckname]
      end
    end

     def do_yield(tex,blck,filter)
#p blck
#p parse(blck[1..-1],filter)
      codename=parse(blck[1..-1],filter)
      make_yield(tex,codename,filter)
    end

    def do_part(tex,blck,filter)
      i=0
      i,*b2=next_block(blck,i)
      file=parse(b2,filter).strip
      # prepare the filename
      file,part=file.split("|").map{|e| e.strip}
      file,out=file.split("#").map{|e| e.strip}
      out=(out ? out.to_sym : @cfg[:format_doc])
      out=:dyn if [:*,:all].include? out
      file=File.join("part",file+"_part"+Dyndoc::EXTS[out])
      # part tags prepended by "part:"
      part=TagManager.make_tags(part.split(",").map{|e| "part:"+e}.join(",")) if part
      #
      if File.exist?(file) and (!part or !TagManager.tags_ok?(part,@tags))
      	puts "partial #{file} loaded"
      	tex += File.read(file)
      else
      	puts "partial #{file} generated"
      	tex2=parse([blck[(i+1)..-1].unshift(:blck)],filter)
      	#puts tex2
      	Dyndoc.make_dir("part")
      	File.open(file,"w") do |f|
          f << tex2
        end
        tex += tex2
      end
    end

  end
  end
end
