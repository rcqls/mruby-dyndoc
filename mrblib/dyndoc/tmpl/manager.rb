# encoding: UTF-8

module Dyndoc
  module MRuby
  
  class TemplateManager
    
    attr_accessor :global, :filterGlobal, :filter, :vars, :libs , :tmpl , :blocks, :calls, :args, :envirs, :fmt, :Fmt, :fmtContainer, :fmtOutput, :dyndocMode ,:echo, :filename, :tags, :strip
    attr_accessor :tmpl_cfg, :cfg_tmpl, :cfg, :doc
    attr_accessor :rbEnvir, :rbEnvirs,  :rEnvir 
    attr_accessor :rbBlock
    attr_reader :scan, :blckName
    ### attr_accessor :mark

    @@interactive=nil
    
    def TemplateManager.interactive
      @@interactive=(!$cfg_dyn.nil? and $cfg_dyn[:dyndoc_session]==:interactive) unless @@interactive
      @@interactive
    end

    # Maybe better located inside server.rb
    def TemplateManager.initR
      first=!R4mrb.alive?
      Dyndoc.warn "FIRST INIT OF R!!!!"
      R4mrb.init
      TemplateManager.interactive
      #p "client";p $cfg_dyn;p interactive
      R4mrb << "rm(list=ls(all=TRUE))" if !first and !@@interactive #remove all initial variables if previous documents session
      R4mrb << ".dynStack<-new.env()" #used for R variables used by dyndoc
      RServer.init_envir 
      RServer.init_filter
      # ## ruby and R init for dynArray stuff
      # require "dyndoc/common/dynArray"
      # lib_root=File.join(File.dirname(__FILE__),[".."]*5) #or $dyn_gem_root
      # R4mrb << "source('"+File.join(lib_root,"share","R","dynArray.R").gsub('\\','/')+"')"
    end

    # def TemplateManager.initJulia
    #   first=require "jl4rb" #save if it the first initialization!
    #   Julia.init
    #   # init rb4jl stuff
    #   # since inside ruby, no need Ruby.start and Ruby.stop like in rb4R.
    #   # sort of equivalent of JLServer.init_filter (but not yet defined)!
    #   lib_root=File.join(File.dirname(__FILE__),[".."]*5) #or $dyn_gem_root
    #   Julia << "include(\""+File.join(lib_root,"share","julia","ruby.jl")+"\")"
    #   Julia << "include(\""+File.join(lib_root,"share","julia","dynArray.jl")+"\")"
    #   #-| To debug ruby.jl and dynArray.jl => uncomment below and commnt above
    #   # Julia << "include(\""+File.expand_path("~/Github/dyndoc/share/julia/ruby.jl")+"\")"
    #   # Julia << "include(\""+File.expand_path("~/Github/dyndoc/share/julia/dynArray.jl")+"\")"
    #   Julia << "using Dyndoc"
    #   Julia << "Ruby.alive(true)"
    #   #Julia << "global const _dynArray=DynArray()"
    #   Dyndoc.warn "Julia initialized inside dyndoc!"

    # end

    def TemplateManager.attr
      attr={:cmd => @@cmd,:cmdAlias => @@cmdAlias, :argsSep => @@argsSep, :tags => @@tags,:prefix => @@prefix, :tagSearch => @@tagSearch, :tagModifiers => @@tagModifiers}
      attr[:tags_tex],attr[:tex_vars] = @@tags_tex,@@tex_vars if TemplateManager.class_variables.include? "@@tag_tex"
      attr
    end
    
    def initialize(tmpl_cfg,with=true)
      # just in case it is not yet initialized!
      $cfg_dyn={} unless $cfg_dyn
      ##p [:mngr_cfg,$cfg_dyn]
      unless $cfg_dyn[:langs]
        $cfg_dyn[:langs]=[] 
        $cfg_dyn[:langs] << :R if with==true
      end

#puts "DEBUT INIT TemplateManager"
      @tmpl_cfg=tmpl_cfg
#=begin
#      @cfg[:part_tag][0]=@cfg[:part_tag][0][1..-1] if !(@cfg[:part_tag].empty?) and (@partTag_add= (@cfg[:part_tag][0][0,1]=="+"))
#=end
      ## default system root appended
      ## To remove: Dyndoc.setRootDoc(@cfg[:rootDoc],Dyndoc.sysRootDoc("root_"+@cfg[:enc]),false)
      TemplateManager.initR if $cfg_dyn[:langs].include? :R
      # TemplateManager.initJulia if $cfg_dyn[:langs].include? :jl
      rbenvir_init(binding)
      @rEnvir=["Global"]
      @envirs={}
      @fmtContainer=[]
      @echo=1
      @strip=true
#puts "FIN INIT TemplateManager"
      if $cfg_dyn and $cfg_dyn[:devel_mode] and $cfg_dyn[:devel_mode]==:test
        puts "DYNDOC SEARCH PATH:"
        puts Dyndoc.get_pathenv($curDyn[:rootDoc]).join(":")
      end
    end

    def init_doc(doc_cfg)
      @cfg=doc_cfg
      # register format
      @fmt=@cfg[:format_doc].to_s.downcase
      @Fmt=@fmt.capitalize
      ##Dyndoc.warn "@cfg",@cfg
      @fmtOutput=@cfg[:format_output].to_s if @cfg[:format_output]
      @fmtOutput=@fmt if @fmt and ["html","tex","odt","tm"].include? @fmt
      @dyndocMode=:cmdline
      @global={}
      @filterGlobal=FilterManager.global(self) #global filter needed to affect object before parsing the main document!
      @blocks,@libs,@calls,@args,@meths,@def_blck={},{},{},{},[],[]
      ####disabled: CallFilter.init(self,@calls,@args,@meths)
      @filter=nil
      @tags=[]
      @keys={}
      @alias={}
      @savedBlocks={}
    end

    def format_output=(format)
      @fmtOutput=format
    end

    def dyndoc_mode=(mode)
      @dyndocMode=mode
    end

    def reinit
      @blocks,@libs={},{}
    end

    ## init output
    def init_path(input)
       ##read in the main doc paths to include!
      Dyndoc.setRootDoc(@cfg[:rootDoc],input.scan(/%%%path\((.*)\)/).flatten.map{|e| e.split(",")}.flatten.map{|e| e.strip.downcase}.join(":"))
      p @cfg[:rootDoc] if @cfg[:cmd]==:cfg
    end

    def init_tags(input)
      ## read the global aliases (config files alias)
      TagManager.global_alias(@alias) # @alias increased
      ## read the local aliases (in the main doc) 
      TagManager.local_alias(@alias,input) # @alias increased 
      #init @partTag
      @tags=TagManager.init_input_tags(([@fmt]+@cfg[:tag_doc]+@tmpl_cfg[:tag_tmpl]).uniq)
#p @alias
#puts "init_tags";p @tags
      #To deal later: TagManager.apply_alias(@tags,@alias)
      p [:init_tags, @tags] if @cfg[:cmd]==:cfg
    end

    def init_keys
      @init_keys=KeysManager.init_keys((@cfg[:keys_doc]+@tmpl_cfg[:keys_tmpl]).uniq)
#puts "Manager:init_keys";p @init_keys
    end
    
    
    def init_model(input)
      @pre_doc,@post_doc,@pre_model,@post_model=[],[],[],[]
      if @cfg[:model_doc] and Dyndoc.cfg_dir[:tmpl_path][@cfg[:format_doc]]
        @cfg[:model_doc]="Default" if @cfg[:model_doc].downcase=="default"
        model_doc=File.join("Model",Dyndoc.cfg_dir[:tmpl_path][ @cfg[:format_doc]],@cfg[:model_doc])
        @pre_model << File.read(Dyndoc.doc_filename(model_doc+"Pre"))
        @post_model = [File.read(Dyndoc.doc_filename(model_doc+"Post"))]
#p @pre_model
#p @post_model
      end

      ## sort with respect to priority number and filter
      @cfg[:pre_doc] += input.scan(/\[\#(?:plugin|preload)\]([^\[]*)/m).flatten.map{|e| e.strip.map{|e2| e2.split("\n").map{|e3| e3.strip}}}.flatten
#p @cfg[:pre_doc]
      input.gsub!(/\[\#(?:plugin|preload)\][^\[]*/m,"")
      @cfg[:pre_doc].sort!.map!{|e| e.scan(/^\d*(.*)/)}.flatten!
      ## sort with respect to priority number and filter
      @cfg[:post_doc] += input.scan(/\[\#(?:postload)\]([^\[]*)/m).flatten.map{|e| e.strip.map{|e2| e2.split("\n").map{|e3| e3.strip}}}.flatten
      input.gsub!(/\[\#(?:postload)\][^\[]*/m,"")
      @cfg[:post_doc].sort!.map!{|e| e.scan(/^\d*(.*)/)}.flatten!

#p @cfg[:pre_doc]
      if @cfg[:pre_doc]
        @cfg[:pre_doc].uniq.each{|t|
          @pre_doc << File.read(Dyndoc.doc_filename(t))
        }
      end
#p @pre_doc
      
      if @cfg[:post_doc] 
        @cfg[:post_doc].uniq.each{|t|
          @post_doc << File.read(Dyndoc.doc_filename(t))
        }
      end

    end

    def output_pre_model
      #pre_doc
      out_pre=""
      unless @pre_model.empty?
        pre_model=@pre_model.join("\n") + "\n"
        txt= pre_model 
        out_pre += parse(txt)
      end
      unless @pre_doc.empty?
        pre_doc=@pre_doc.join("\n") + "\n"
        txt= pre_doc 
        parse(txt,@filterGlobal) ##Style declares objects before compiling the document! Object are created in the global envir!
      end
#p out_pre
      return out_pre
    end
#=begin
#      input = pre_doc.join("\n") + "\n" + input unless pre_doc.empty?
#      input = input + "\n" + post_doc.join("\n") unless post_doc.empty?
#      return input
#=end

    def output_post_model
     #post_doc
      out_post=""
      #puts "output_post_model:post doc";p @post_doc
      unless @post_doc.empty?
        post_doc="\n"+@post_doc.join("\n")
        txt= post_doc 
        parse(txt)
      end
      unless @post_model.empty?
        post_model="\n"+@post_model.join("\n")
        txt= post_model 
        out_post += parse(txt)
      end
#p out_post
      return out_post
    end


    ## TO REMOVE????
    def init_dtag(tmpl)
      dtag=tmpl.scan(/(?:#{@cfg[:dtags].map{|e| "_#{e}_" }.join("|")})/)[0]
#p dtag
      return @dtag=(dtag ? dtag[1...-1].to_sym : @cfg[:dtag])
    end

    def prepare_output(txt)
      ## parse the content txt
      out=output_pre_model
#p out
#p $dyn_firstblock
      ## $dyn_firstblock called in preloaded libraries!
      out += parse($dyn_firstblock) if $dyn_firstblock
#puts "prepare_output";p out 
      out += parse(txt)
#puts "prepare_output";p out
      ## $dyn_lastblock (for example, used to record some information)
      out += parse($dyn_lastblock) if $dyn_lastblock
      out += output_post_model
      ## escape=true at the end in order to transform undefined variables in Latex!!!
##puts "prepare output: BEFORE apply";puts out
      out=@filter.apply(out,:post,false,true) if [:tex,:odt,:ttm,:html].include? @cfg[:format_doc]
##puts "prepare output: AFTER apply";puts out
      #escape accolade!
      Utils.escape!(out,CHARS_SET_LAST)
##puts "prepare output: AFTER Utils.escape!";puts out
      out=Utils.unprotect_format_blocktext(out)
##puts "prepare output: AFTER Utils.unprotect_format_blocktext";puts out
      return out
    end

    ##only once!!! Not like prepare_output which is called in {#dyn]pre:
    def prepare_last_output(out)
      #puts "DYNDOC_RAW_TEXT! BEFORE";p out
      #p Utils.dyndoc_raw_text
      Utils.dyndoc_raw_text!(out,:clean=>true)
      #puts "DYNDOC_RAW_TEXT! AFTER";p out
      return out
    end

    def clean_as_is(out)
      out.gsub!(Dyndoc::AS_IS,"")
    end

    def prepare_user_input
      ##puts "input";p @cfg[:input];p $cfg_dyn[:user_input]
      if @cfg[:input]
        @global["_"]={} unless @global["_"]
        @cfg[:input].each{|k,v|
          @global["_"][k.to_s] = {:val=>[v]}
        }
      end
      if $cfg_dyn[:user_input]
        @global["_"]={} unless @global["_"]
        $cfg_dyn[:user_input].each{|k,v|
          @global["_"][k.to_s] = {:val=>[v]}
        }
      end
    end

    ## output the result after parsing txt
    def output(input,fromfile=nil)
      @filename=@tmpl_cfg[:filename_tmpl]
      input=Dyndoc.input_from_file(@filename=input) if fromfile
      ## fetch the contents of all saved variables! This fasten the compilation!
      Utils.saved_content_fetch_variables_from_file(@filename,self)

#p @filename
      init_path(input)
      init_tags(input)
      init_keys
      init_model(input)
#p input
      ## add the tag document in order to replace the user tag preamble and etc. Introduction of styles because of the odt format and the new convention in general to use styles even in latex. 
      #txt="{#document][#content]"+input+"[#}"
      txt=input
#p txt
      prepare_user_input
      ## parse the content txt
      out=prepare_output(txt)
      prepare_last_output(out)
      clean_as_is(out)
      return out
    end

    def query_library(libname)
      init_doc({:format_doc=>:tex})
      parse(Dyndoc.input_from_file(libname))
      p @calls.keys.sort
      p @meths.sort
    end

  end

  end
end

# String helpers ######################

class String

  def to_keys
    Dyndoc::Envir.to_keys(self)
  end

  def to_dyn
    if $dyn
      return $dyn.tmpl.parse_string(self)
    else 
      return self
    end
  end

  def to_var
    if $dyn and (res=$dyn.tmpl.vars.extract(self))
      res
    else
      self
    end
  end

  def to_var=(val)
    if $dyn
      $dyn.tmpl.vars[self]=val
    end
  end

end

