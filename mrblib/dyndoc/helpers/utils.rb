# encoding: utf-8

module Dyndoc

  CHARS_SET_FIRST=[["_{_","__OPEN__"],["_}_","__CLOSE__"]]
  CHARS_SET_LAST=[["__OPEN__","{"],["__CLOSE__","}"]]
  PROTECT_FORMAT_BLOCKTEXT="<protect-format-blocktext>"

  module Utils
## variable sep!
    def Utils.split_code_by_sep(code,sep="|")
      return code.split("\n").map{|e| e.split(sep)}.flatten
    end

    def Utils.preserve_pattern(line,pattern,chars)
        line.gsub(pattern){|s| Utils.escape(s,chars)}
    end

    ## used in [\#var] and [\#set]
    ## protect "|" inside @{toto(...)}
    def Utils.split_code(code,pattern=/@\{.*\}/,chars=["|","@@@"])
      inst=Utils.preserve_pattern(code,pattern,chars)
      inst,*b=inst.split(/\n\-{3,}\n/)
      b=inst.strip.split("\n").map{|e| e.split(chars[0])}.flatten+b if inst
      b.map!{|l| Utils.preserve_pattern(l,pattern,chars.reverse)}
      return b
    end

    def Utils.silence_warnings(val=nil)
      old_verbose, $VERBOSE = $VERBOSE, val
      yield
    ensure
      $VERBOSE = old_verbose
    end

    def Utils.make_doc(txt)
      out=txt.split("\n")
      ## Ajout  surement du à kile qui rajoutte des "\r" => générant un bug dans R
      out.map!{|e| (e[-1,1]=="\r" ? e[0...-1] : e )}
      return out
    end

    # TOOLS ###################################
    def Utils.clean_comment(b)
      b.map!{|l| ( l.scan(/([^%]*)(%%.*)/)[0] ? $1.strip : l)}.reject!{|e| e.empty?}
    end

    def Utils.clean_indent(b)
      start,key=b[0].scan(/(\s*)([^\s]*)/)[0]
      if start.length>0
        b.map!{|l|
          ( (l.index start)==0 ? l[start.length,l.length-start.length] : l )
        }
      end
    end

    def Utils.escape(str,chars)
      str.gsub(/#{Regexp.escape(chars[0])}/,chars[1])
    end

    def Utils.escape!(str,chars_set)
      chars_set.each{|chars| str=str.gsub(/#{Regexp.escape(chars[0])}/,chars[1]) }
      return str
    end
    
    def Utils.escape_delim!(str,mode=:last)
      chars_set=(mode==:first ? CHARS_SET_FIRST : CHARS_SET_LAST )
      chars_set.each{|chars| str=str.gsub(/#{Regexp.escape(chars[0])}/,chars[1]) }
      return str
    end  

    def Utils.end_line(key,code)
      while key[-1,1]=="\\"
        key=(key[0...-1]+(code.shift)).strip
      end
      return [key,code]
    end

    def Utils.clean_eol!(str)
      str=str.gsub("\r\n","\n")
      return str
    end

    def Utils.clean_bom_utf8!(str)
      str=str.gsub("\xEF\xBB\xBF", '')
      str
    end

# To consider first and last whitespaces put before and after an escaped sequence! Before the string is formatted for indentation convenience!
    def Utils.protect_blocktext(str,seq="__STR__")
	#str=code+str if str[0,1]==" "
	#str=str+code if str[-1,1]==" "
#puts "protect_blocktext";p str
#puts "format_blocktext";p Utils.format_blocktext(str)
      seq+Utils.format_blocktext(str)+seq
    end

# When considered, remove the escaped sequence!
    def Utils.unprotect_blocktext(str,seq="__STR__")
#puts "unprotect blocktext";p str
      str.gsub(seq,"")
    end
    
    def Utils.format_blocktext(str)
      str.gsub(/\n[ \t\r\f]*\|/,"\n").gsub(/\|\n/,"").gsub("<\\n>","\n").gsub("<\\t>","\t")
    end

#called in #txt to protect the corresponding blocktext
    def Utils.protect_format_blocktext(str)
       str.gsub(/\n[ \t\r\f]*\|/) {|e| e.gsub(/\|/,"__BLOCKBAR__")}.gsub(/\|\n/,"__BLOCKBAR__\n").gsub("<\\n>","__BLOCKSPACE__").gsub("<\\t>","__BLOCKTAB__")
    end

    def Utils.unprotect_format_blocktext(str)
      str.gsub("__BLOCKBAR__","|").gsub("__BLOCKSPACE__","<\\n>").gsub("__BLOCKTAB__","<\\t>").gsub("__RAW__","")
    end

    def Utils.protect_txt_block(str)
      str2=Utils.protect_format_blocktext(str)
      str2=Utils.escape!(str2,[["{","_{_"],["}","_}_"]])
      str2=Utils.escape_delim!(str2,:first)
      str2
    end

    def Utils.protect_extraction(str)
      str.gsub(/(?:\#|\#\#|@|#F|#R|#r|\:R|\:r|#Rb|#rb|\:|\:Rb|\:rb)+\{/) {|e| "\\"+e}
    end

    ## the scanner converts automatically  {#toto#} in {#toto][#} and   {@toto@} in {@toto][#}
    ## this function does the convert when needed for verbatim or code.
    def Utils.format_call_without_param(code)
      code.gsub(/\{(\#|\@)(\w*)\]\[\#\}/,'{\1\2\1}')
    end

    def Utils.format_call_without_param!(code)
      code=code.gsub(/\{(\#|\@)(\w*)\]\[\#\}/,'{\1\2\1}')
      code
    end

    def Utils.uuidgen
      `uuidgen`.strip
    end


    # @@raw_text,@@raw_key,@@raw_var_ls=[],[],[]

    # ## multilines is for @verbatim which behaves differently depending on the number of lines in the content
    # ## when the key replaces the content this solves the problem!
    # def Utils.dyndoc_raw_text_key(key=nil,multilines=nil)
    #   "__"+(key=( key ? key : "" ))+"|"+Utils.uuidgen+"__"+(multilines ? "\n__"+key+"__" : "")
    # end

    # ## add a raw text
    # def Utils.dyndoc_raw_text_add(raw_text,key=nil,gen_key=true)
    #   @@raw_key << (key=(gen_key ? Utils.dyndoc_raw_text_key(key,raw_text=~/\r?\n/) :  key ))
    #   @@raw_text << [raw_text] #like a pointer!
    #   #puts "dyndoc_raw_text:key";p key
    #   key
    # end

    ## find a raw text
    # def Utils.dyndoc_raw_text(key=nil)
    #   if key
    #     ind=@@raw_key.index{|e| e==key or e=~/^\_\_#{key}/}
    #     #p (ind ? @@raw_text[ind][0] : nil)
    #     (ind ? @@raw_text[ind][0] : nil)
    #   else
    #     [@@raw_key,@@raw_text]
    #   end
    # end

    ## apply replacement in out
    # def Utils.dyndoc_raw_text!(out,opt={:clean=>nil,:once=>nil})
    #   @@raw_key.each_index do |i|
    #     #p [@@raw_key[i],@@raw_text[i]]
    #     #begin puts @@raw_key[i];p @@raw_text[i];puts @@raw_text[i]; end #if i==1
    #     @@raw_text[i][0] = @@raw_text[i][0].gsub('\\\\','\\\\\\\\\\')
    #     out=out.gsub(@@raw_key[i],@@raw_text[i][0]) #if the result is placed into a dyn variable, it can be repeated!
    #     @@raw_text[i][0]="" if opt[:once] #used only once!!! Ex: used by raw.
    #   end
    #   @@raw_text,@@raw_key=[],[] if opt[:clean]
    #   ##puts "dyndoc_raw:out";puts out
    #   return out
    # end

    # RAW_TAGS={"{#code]"=>"[#code}","{#raw]"=>"[#raw}"}
    # RAW_LANG={"r"=>"R","rb"=>"ruby"}


    # ## Just used inside do_rb in parse_do.rb file to save rbcode before process_rb!
    # @@raw_code_to_process=true
    # def Utils.raw_code_to_process=(state=nil)
    #     @@raw_code_to_process=state
    # end

    # def Utils.raw_code_to_process
    #   return @@raw_code_to_process
    # end



    # def Utils.parse_raw_text!(txt,tmplMngr=nil)
    #   #puts "parse_raw_text:";p txt
    #   filter=/(?:(\{\#code\]|\{\#raw\])(\s*[\w\.\-_:]+\s*)(\[\#(?:dyn|R|r|ruby|rb)(?:\>|\<)?\]\n?)|(\[\#code\}|\[\#raw\}))/m
    #   txt2=txt.split(filter,-1)
    #   return if txt2.length==1
    #   #Dyndoc.warn "parse:txt2",txt2
    #   code=""
    #   while txt2.length>1
    #     if RAW_TAGS.keys.include? txt2[0] and txt2[1..-1].include? RAW_TAGS[txt2[0]]
    #       tag,name,lang=txt2.shift(3)
    #       name=~/\s*([\w\.\-_:]+)\s*/
    #       name=$1
    #       lang=~/\[\#(dyn|R|r|ruby|rb)(\>|\<)?\]/
    #       lang,type=$1,$2
    #       lang="dyn" unless lang
    #       lang=RAW_LANG[lang] if RAW_LANG[lang]
    #       type="<" unless type
    #       code2=""
    #       code2 << txt2.shift until txt2[0]==RAW_TAGS[tag]
    #       #puts "parse_raw_text:name,type,mode,code";p [name,type,lang,code2]
    #       key=Utils.dyndoc_raw_text_add(code2,name+"-"+lang)
    #       #puts "parse_raw_text:key added";p key
    #       code << key if type==">"
    #       if tmplMngr
    #         ## puts inside global envir! 
    #         envir=tmplMngr.filterGlobal.envir
    #         envir[lang+"."+name+".name"]=key
    #         envir[lang+"."+name+".code"]=@@raw_text[-1]
    #         ## "content" would be the name of the result after evaluation and saved in <dyn_basename_file>.dyn_out/raw_code.dyn 
    #       end
    #       @@raw_var_ls << lang+"."+name #
    #       txt2.shift #last close tag!
    #     else
    #       code << txt2.shift
    #     end
    #   end
    #   code << txt2.join("") #the remaining code

    #   ##OLD: @@raw_key_index=@@raw_key.map{|key| key=~/\_\_(.*)\|(.*)/ ? $1 : nil}.compact
    #   ##puts "code";p code
    #   if RUBY_ENGINE=="opal"
    #     return code
    #   else
    #     txt.replace(code)
    #     return txt
    #   end
    # end

    # def Utils.dyndoc_raw_var_ls
    #   @@raw_var_ls
    # end

    # def Utils.dyndoc_raw_var_eval(var,tmplMngr=nil) #var differs from key since it is saved in filter! 
    #   return "" unless tmplMngr
    #   #p var
    #   return ((@@raw_var_ls.include? var) ? tmplMngr.parse(tmplMngr.filterGlobal.envir[var+".code"]) : "" )
    # end

    # def Utils.dyndoc_raw_var_save(var,tmplMngr=nil)
    #   return  unless tmplMngr
    #   #puts "raw_var_save_content";p var+".content"
    #   envir=tmplMngr.filterGlobal.envir
    #   content=Utils.dyndoc_raw_var_eval(var,tmplMngr)
    #   #p content
    #   envir[var+".eval"]=content
    #   #for next compilation
    #   Utils.saved_content_add_as_variable(var+".eval",content,tmplMngr.filename)
    # end

    # def Utils.dyndoc_raw_var_content(var,tmplMngr=nil)
    #   return ""  unless tmplMngr
    #   #puts "var_content";p var+".content"
    #   #p tmplMngr.filter.envir.global["dyn"]
    #   #p tmplMngr.filterGlobal.envir
    #   Utils.dyndoc_raw_var_save(var,tmplMngr) if !tmplMngr.filterGlobal.envir[var+".eval"] or Utils.saved_content_to_be_recreated(tmplMngr).include? var
    #   tmplMngr.filterGlobal.envir[var+".eval"]
    # end

    # SAVED_CONTENTS_FILE="saved_contents.dyn"

    # def Utils.saved_content_fetch_variables_from_file(filename,tmplMngr=nil)
    #   return unless tmplMngr
    #   #p filename
    #   return unless out_rsrc=Dyndoc::Utils.out_rsrc_exists?(filename)
    #   return unless File.exists?(saved_contents_file=File.join(out_rsrc,SAVED_CONTENTS_FILE)) ##normally, autogenerated!
    #   #p out_rsrc
    #   ## fetch the contents by reading and parsing unsing the global filter!
    #   #puts "saved_contents_file";p saved_contents_file
    #   code="{#document][#main]"+File.read(saved_contents_file)+"[#}"
    #   tmplMngr.parse(code,tmplMngr.filterGlobal)
    #   #puts "fetch var:dyn";p tmplMngr.filter.envir.global["dyn"]
    # end

    # @@saved_content_ls=[]
    # @@saved_content_to_be_recreated=nil

    # def Utils.saved_content_to_be_recreated(tmplMngr)
    #   unless @@saved_content_to_be_recreated
    #     user_input=tmplMngr.filterGlobal.envir["_.EVAL"]
    #     @@saved_content_to_be_recreated=(user_input ? user_input.strip.split(",") : [])
    #   end
    #   @@saved_content_to_be_recreated
    # end

    # def Utils.saved_content_add_as_variable(var,result,filename) #var is dyndoc variable
    #   ##p filename
    #   out_rsrc=Dyndoc::Utils.mkdir_out_rsrc(filename)
    #   unless File.exists? File.join(out_rsrc,SAVED_CONTENTS_FILE)
    #     File.open(File.join(out_rsrc,SAVED_CONTENTS_FILE),"a") do |f|
    #       f << "[#%] File automatically generated! Remove it for regenerating it!\n"
    #     end
    #   end
    #   ## if it alread exist, delete it first!
    #   Utils.saved_content_delete_as_variable(var,filename)
    #   File.open(File.join(out_rsrc,SAVED_CONTENTS_FILE),"a") do |f|
    #     f << "[#=]"+var+"["+result+"]\n"
    #   end
    #   @@saved_content_ls << var
    # end

    # def Utils.saved_content_delete_as_variable(var,filename)
    #   return unless out_rsrc=Dyndoc::Utils.out_rsrc_exists?(filename)
    #   return unless File.exists?(saved_contents_file=File.join(out_rsrc,SAVED_CONTENTS_FILE))
    #   saved_contents=File.read(saved_contents_file)
    #   ## Normally, no problem since no [#=] inside result!
    #   saved_contents_new=saved_contents.gsub(/\[\#\=\]\s*#{var}\s*\[.*\]\s*\[\#\=\]/m,"[#=]")
    #   unless saved_contents==saved_contents_new
    #     File.open(File.join(out_rsrc,SAVED_CONTENTS_FILE),"w") do |f|
    #       f << saved_contents_new
    #     end
    #     @@saved_content_ls.delete(var)
    #   end
    # end

    # def Utils.saved_content_ls
    #   return @@saved_content_ls
    # end

    # def Utils.saved_content_get(var,tmplMngr=nil,force=nil)
    #   return unless tmplMngr
    #   if force
    #     return (Utils.saved_content_to_be_recreated(tmplMngr).include? var) ? nil : tmplMngr.filterGlobal.envir[var]  
    #   else
    #     return tmplMngr.filterGlobal.envir[var]
    #   end
    # end

    # ## Added for atom
    # def Utils.protect_dyn_block_for_atom(txt)
    #   txt.gsub("#","__DIESE_ATOM__") # => since dyndoc command uses "#" this is very easy way to protect evaluation 
    # end

    # def Utils.parse_dyn_block_for_atom!(txt)
    #   #Dyndoc.warn "parse_dyn_block_for_atom",txt
    #   filter=/(?:(\{\#dyn>\])|(\[\#dyn>\}))/m
    #   txt2=txt.split(filter,-1)
    #   return if txt2.length==1
    #   #Dyndoc.warn "parse:txt2",txt2
    #   code=""
    #   while txt2.length>1
    #     if txt2[0]=="{#dyn>]" and txt2[1..-1].include? "[#dyn>}"
    #       start,tmp,stop=txt2.shift(3)
    #       ## protect the dyndoc code to delay the evaluation after unprotection (in javascript)
    #       code << Utils.protect_dyn_block_for_atom(tmp.inspect) 
    #     else
    #       code << txt2.shift
    #     end
    #   end
    #   code << txt2.join("") #the remaining code
    #   #Dyndoc.warn "atom",code
    #   if RUBY_ENGINE=="opal"
    #     return code
    #   else
    #     txt.replace(code)
    #     return txt
    #   end
    # end

  end
end
