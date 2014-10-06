module Dyndoc

  class Envir

    attr_accessor :local, :global
    attr_reader :curenv
    
    def initialize(envir)   
      @local=envir[:local]
      @global=envir[:global]
      @local={} unless @local
      @global={} unless @global
      @curenv=nil
    end
  
    @@start=FilterManager.delim[0]
    @@stop=FilterManager.delim[1]

# VarElement methods ###########################
    def Envir.is_textElt?(e)
      (!e.nil?) and ((e.is_a? Hash) and e[:val])
    end

    #same as below but including Array of textElt
    def Envir.is_textValElt?(e)
      (!e.nil?) and (((e.is_a? Hash) and e[:val]) or ((e.is_a? Array) and e.all?{|ee| Envir.is_textValElt?(ee)}))
    end

    def Envir.typeElt(e)
      return :nil if e.nil?
      return :text if (e.is_a? Hash) and e[:val]
      return :list
    end

    def Envir.is_listElt?(e)
      !e.nil? and !Envir.is_textElt?(e)
    end

    def Envir.to_textElt(ary)
      return ary if Envir.is_textElt?(ary)
      ary=[[ary]] if ary.is_a? String 
      res={:val=>((ary[0].is_a? Array) ? ary[0] : [ary[0]] ) }
      res[:attr]=ary[1] if ary[1]
      return res 
    end

    def Envir.to_textVal(e)
      if Envir.is_textElt?(e)
        return e[:val][0]
      else
        out=nil
        if e.is_a? Array
          out=[]
          e.map{|ee| out << Envir.to_val(ee)}
        end
        return out.join
      end
    end

# here Hash is considered!
    def Envir.to_val(e)
      if Envir.is_textElt?(e)
        return e[:val][0]
      else
        out=nil
        if e.is_a? Array
          out=[]
          e.map{|ee| out << Envir.to_val(ee)}
        end
        if e.is_a? Hash
          out={}
          e.map{|k,ee| out[k]=Envir.to_val(ee)}
        end
        return out
      end
    end
   
    def Envir.to_keys(key)
      keys=key.strip.split(".")
      ## keys=["1","ta"] -> keys=[1,"ta"]
      keys.map!{|e| (e.to_i.to_s==e ? e.to_i : e)}
      return keys
    end

    def Envir.update_textElt(elt,ary)
      tmp=Envir.to_textElt(ary)
      elt[:val].replace(tmp[:val])
      if tmp[:attr]
        elt[:attr]=[] unless elt[:attr]
        elt[:attr].replace(tmp[:attr])
      end
    end
  
    #cur responds is Array or Hash and ary is Array
    def Envir.update_elt(cur,key,ary)
#puts "in update_elt";p cur; p key; p ary
      if Envir.is_textElt?(cur[key])
        Envir.update_textElt(cur[key],ary)
      else
        cur[key]=Envir.to_textElt(ary)
      end
#p cur
    end

# ACCESS Envir ###############################

##########################
# return curElt if exists? and text
# return curEnv if exists? and !text
# if text then check if the element is textElt 
##########################
    def Envir.elt_defined?(envir,keys,text=nil)
#puts "Envir.elt_defined?"; p envir; p keys; p text
      return nil if keys.empty?
      if keys.length==1
        ok=envir.include?(keys[0])
        ok &= Envir.is_textValElt?(envir[keys[0]]) if text
        return (ok ? (text ? envir[keys[0]] : envir) : nil)  
      end
      curEnv=envir
#puts "envir";p envir
      i=0
      curElt=nil
      while (curElt != "ERR:[]?" and i<keys.length-1)
        curEnv=curEnv[keys[i]]
        i+=1
        curElt=begin curEnv[keys[i]] rescue "ERR:[]?" end 
        #puts "curElt";p curElt
      end 
      ok=(curElt != "ERR:[]?")
      ok &= Envir.is_textValElt?(curElt) if text
#puts "envir2";p envir
      return ((ok and curElt) ? (text ? curElt : curEnv) : nil)
    end

    def elt_defined?(keys,text=nil)
      return ( keys_defined?(keys) ? Envir.elt_defined?(@curenv,keys,text) : nil)
    end

    def elt_and_envir(keys,text=nil)
      return ( keys_defined?(keys) ? [Envir.elt_defined?(@curenv,keys,text),@curenv] : nil )
    end

# Added: 5/9/08 for use in eval_CALL!
# this is a replacement of Envir.get_elt! only used in eval_CALL
#TODO: check if it is necessary to get global variable! TO TEST!
    def Envir.keys_defined?(envir,k)
      return envir if Envir.elt_defined?(envir,k)
      local,curenv=envir,nil
      if local.include? :prev
	begin
	  local=local[:prev]
	  curenv=local if Envir.elt_defined?(local,k)
	end until curenv or !(local[:prev])
      end
      return(curenv)
    end

#################
## return the hash if the keys is defined!!!
## @curenv is then set
##################
    def keys_defined?(k,locally=false) ##old name defined? already existing -> bug in export 
      @curenv=nil
      @curenv=@local if Envir.elt_defined?(@local,k)
      return(@curenv) if @curenv and locally != :out
      if @local.include? :prev
      	local=@local
      	begin
      	  local=local[:prev]
      	  @curenv=local if Envir.elt_defined?(local,k)
      	end until @curenv or !(local[:prev])
      end
      return(@curenv) if @curenv
      @curenv=@global if Envir.elt_defined?(@global,k)
      ##print 'before-> ';p @curenv
      return(@curenv) if @curenv
      ## special treatment for export in mode :out
      if locally==:out
        @curenv=@global
        return nil #no element found but @curenv is fixed
      end
      @curenv=(locally ? @local : @global)
      ##print "key_defined?"+k+"\n";p @curenv
      return nil
    end

# for debug ##############################################
    def test_keys(keys)
      puts "keys_defined?(#{keys.join('.')})"
      p keys_defined?(keys)
      puts "keys_defined?(#{keys.join('.')},true)"
      p keys_defined?(keys,true)
      puts "elt_defined?(#{keys.join('.')})"
      p elt_defined?(keys)
      puts "elt_defined?(#{keys.join('.')},true)"
      p elt_defined?(keys,true)
    end


    ############################################
    # curEnv[key1] exists! and curEnv[key1][key2] ??? 
    # return curEnv
    ############################################
    def Envir.get_next_elt!(res,keys,i) 
      curEnv=res[keys[i]]
#p i;p res;p keys[i];p keys[i+1]
      test=begin curEnv[keys[i+1]] rescue "ERR:[]?" end
#p test;p curEnv
      if test=="ERR:[]?"
        #create it
        if keys[i+1].is_a? Integer
          res[keys[i]]=curEnv=[] unless res[keys[i]].is_a? Array
          curEnv[keys[i+1]]=nil
        elsif keys[i+1].is_a? String
          res[keys[i]]=curEnv={} unless res[keys[i]].is_a? Hash
          #curEnv[keys[i+1]]=nil #useless with respect to Array
        end
      elsif test.nil? and keys[i+1].is_a?(Integer) and !res[keys[i]].is_a?(Array)
        ## check that res[keys[i]] is of the expected type because res[1] is ok when res is a Hash!!!!
        res[keys[i]]=curEnv=[]
        curEnv[keys[i+1]]=nil
      end
#p test;p res;p cur
      # now cur responds to cur[keys[i+1]]
      i += 1
      if keys[i+1]
        Envir.get_next_elt!(curEnv,keys,i)
      else
        return curEnv 
      end
    end


    #return curEnv and not directly curElt because of dynamic tricks! curElt is then obtained by curEnv[keys[-1]]
    def Envir.get_elt!(envir,keys)
      return nil if keys.empty?
      if keys.length==1
        return envir
      end
      return Envir.get_next_elt!(envir,keys,0)
    end


    def Envir.set_elt!(envir,keys,v)
      curEnv=Envir.get_elt!(envir,keys)
#puts "in set_elt!";
#p envir
#puts "curEnv";p curEnv;p curEnv[keys[-1]];p keys;p v
#=begin
      if curEnv
        #if curEnv.respond_to? "[]" and curEnv[keys[-1]]
          Envir.update_elt(curEnv,keys[-1],v)
        #else
        #create it! ADD: 06/03/08! Surtout pour les affectations par variable!
          #curEnv[keys[-1]]=v
#puts "created";p keys[-1];p curEnv
        #end
      end
#puts "modif";p curEnv
#=end
    end

    def Envir.set_textElt!(envir,keys,v)
      #only textElt since update_elt have to the curEnv!!!
      curElt=Envir.elt_defined?(envir,keys,true)
      if curElt
        Envir.update_textElt(curElt,v)
      else #otherwise create it!
        Envir.set_elt!(envir,keys,v)
      end
    end

    def set_textElt!(keys,v,envir=nil)
      #only textElt since update_elt have to the curEnv!!!
      curElt,envir=elt_and_envir(keys,true) unless envir
      if curElt
        Envir.update_textElt(curElt,v)
      else #otherwise create it in local environment!
        Envir.set_elt!(envir,keys,v)
      end
    end

 
  
    ##RMK: seems to be unused: FALSE in @vars[:key]
    def [](key,global=nil)
      key=key.to_s.strip
      global,key="global",key[2..-1] if key[0,2]=="::"
      key=key[1..-1] if key[0,1]==":"
      keys=Envir.to_keys(key)
#puts "Envir:[]:keys,filter";p keys;p self
      curElt=nil
      if global and ((tmp=global.to_s.downcase)=="global"[0,tmp.length])
        return curElt[:val][0] if (curElt=Envir.elt_defined?(@global,keys,true))
      else
        return curElt[:val][0] if (curElt=elt_defined?(keys,true))
      end
      return nil
    end

    # same as [] except that result is not necessarily a textElt
    def extract(key)
      key=key.to_s.strip
      global=nil
      global,key="global",key[2..-1] if key[0,2]=="::"
      key=key[1..-1] if key[0,1]==":"
      key=keyMeth(key)
      keys=Envir.to_keys(key)
#puts "Envir:[]:keys,filter";p keys;p self
#puts "keys";p keys
      cur=nil
      if global
        return Envir.to_val(cur[keys[-1]]) if (cur=Envir.elt_defined?(@global,keys))
      else
        return Envir.to_val(cur[keys[-1]]) if (cur=elt_defined?(keys))
      end
      return nil
    end


    def remove(key)
      key=key.to_s.strip
      global=nil
      global,key="global",key[2..-1] if key[0,2]=="::"
      key=key[1..-1] if key[0,1]==":"
      key=keyMeth(key)
      keys=Envir.to_keys(key)
#puts "Envir:[]:keys,filter";p keys;p self
     cur=nil
#puts "keys";p keys
      if global
#p Envir.elt_defined?(@global,keys)
        cur.delete(keys[-1]) if (cur=Envir.elt_defined?(@global,keys))
      else
#p elt_defined?(keys)
        cur.delete(keys[-1]) if (cur=elt_defined?(keys))
      end
    end

    def extract_raw(key)
      key=key.to_s.strip
      global=nil
      global,key="global",key[2..-1] if key[0,2]=="::"
      key=key[1..-1] if key[0,1]==":"
      key=keyMeth(key)
      keys=Envir.to_keys(key)
#puts "Envir:[]:keys,filter";p keys;p self 
     cur=nil
#puts "keys";p keys
      if global
#p Envir.elt_defined?(@global,keys)
        return cur[keys[-1]] if (cur=Envir.elt_defined?(@global,keys))
      else
#p elt_defined?(keys)
        return cur[keys[-1]] if (cur=elt_defined?(keys))
      end
      return nil
    end

    def extract_list(key,elt=nil)
      last_return = !elt
      elt=extract_raw(key) unless elt
      res=[]
      if elt
        if Envir.is_listElt?(elt)
	        if elt.is_a? Hash
	          elt.keys.each{|k|
	            res += extract_list(key+"."+k,elt[k])
	          }
	        else #is_a? Array
	          elt.each_index{|k|
	            res += extract_list(key+"."+k.to_s,elt[k])
	          }
	        end
          return res unless last_return 
        else
          return [key+": ["+Envir.to_val(elt)+"]"]
        end
      end
      if last_return
        res.sort.join("\n")
      end
    end

# IMPORTANT: key may have 3 forms 
# 1) :key or "key" -> key="key" and envir=@curenv
# 2) ":key"        -> key="key" but envir=@local
# 3) "::key"       -> key="key" but envir=@global
# TODO: extend to val a general element and not only a textElt!
    def []=(key,val)
      envir=nil
      default=nil
      key=key.to_s.strip
      #puts "key";p key
      default,key=true,key[1..-1] if key[0,2]=="?:" or key[0,3]=="?::"
      envir,key=@global,key[2..-1] if key[0,2]=="::"
      envir,key=@local,key[1..-1] if key[0,1]==":"
      keys=Envir.to_keys(key)
# #=begin
# puts "[]="
# p keys
# p envir
# p "ici"
# p Envir.elt_defined?(envir,keys,true) if envir
# #=end
      if envir
        if  (curElt=Envir.elt_defined?(envir,keys,true))
          #puts "ici";p curElt
          Envir.update_textElt(curElt,val) unless default
        else
          Envir.set_textElt!(envir,keys,[val])
        end
      else
        if (curElt=elt_defined?(keys,true))
          Envir.update_textElt(curElt,val) unless default
        else
          #create it only locally!
          Envir.set_textElt!(@local,keys,[val])
#p keys; p val
#p @local
        end
      end
    end

##################
# get_by_mode: trick with mode consideration!
#################
    def Envir.get_by_mode(mode,envirType,key,elt)
#puts "get_by_mode:key,elt";p key;p elt
      case mode
      when :pre
	      ## comment : not return "#{"+key+"}" which fails -->  "+key+"
	      return '#'+(envirType==:global ? '#'  : '' )+'{'+key+'}'  unless elt[:attr] and (elt[:attr].include? :pre)
      when :post
	      if Envir.is_textElt?(elt) and elt[:attr] and (elt[:attr].include? :post)
	        return  Envir.to_textVal(elt) #elt[:val][0]
	      end
      end
      return '#'+(envirType==:global ? '#'  : '' )+'{'+key+'}'  if Envir.is_textElt?(elt) and elt[:attr] and (elt[:attr].include? :post)
      return Envir.to_textVal(elt) #elt[:val][0]
    end

    def Envir.extraction_make(keys)
      key_extract=nil
      keys,key_extract=keys[0...-1],keys[-1][1...-1] if keys[-1]=~/^\(.*\)$/
      return [keys,key_extract]
    end

    def Envir.extraction_apply(val,key_extract)
      if key_extract
	if val.is_a? Hash
	  if key_extract[0,1]=="-"
	    key_extract=key_extract[1..-1].split(",")
	  else
	    key_extract=val.keys - key_extract.split(",")
	  end
#p key_extract
	  return val.reject{|k,v| key_extract.include? k}
	elsif val.is_a? Array
	  if key_extract[0,1]=="-"
	    key_extract=(0...(val.length)).to_a-key_extract[1..-1].split(",").map{|e| e.to_i}
	  else
	    key_extract= key_extract.split(",").map{|e| e.to_i}
	  end
#p key_extract
	  val2=[]
	  val.each_index{|i|
	    val2 << val[i] if key_extract.include? i
	  }
	  return val2
	end
      else
	return val
      end
    end

    

    def keyMeth(key)
      return ((@local["self"] and key[0,1]==".") ? "self"+key : key)
    end

    def output(w,mode=nil,escape=false)
      curElt=nil
      emptyElt=nil
      ## GLOBAL variable!!!
      if w[0,2]=="##"
        k=w[3..-2] #the key
        k=k[1..-1] if (emptyElt=(k[0,1]=="?"))
        keys=Envir.to_keys(k)
	      piece=nil
	      piece=Envir.get_by_mode(mode,:global,k,curElt) if  (curElt=Envir.elt_defined?(@global,keys,true))
	      if piece.nil?
          return "" if emptyElt
          ## The following added in order that if a local variable exists 
          ## but not the corresponding global variable, the local variable is interpreted!
          return "#"+Envir.get_by_mode(mode,:local,keyMeth(k),curElt) if (curElt=Envir.elt_defined?(@local,Envir.to_keys(keyMeth(k)),true))
	        return (escape ? "\\#\\#"+@@start+k+@@stop : w)
	      else
	        return piece ##(escape ? Dyndoc.escape(piece) : piece)
	      end
      else
	      ## LOCAL variable!!!
	      k=w[2..-2] #the key
        k=k[1..-1] if (emptyElt=(k[0,1]=="?"))
#p k; p emptyElt
        k=keyMeth(k)
        keys=Envir.to_keys(k)
#puts "keys";p keys
	      piece=nil
        if (curElt=Envir.elt_defined?(@local,keys,true))
	        piece=Envir.get_by_mode(mode,:local,k,curElt)
        end 
#puts "curElt";p curElt
#p self
#p @local
	## except if @mode== :post !!!
	      if mode != :post and !piece and (@local.include? :prev)
	        local=@local
	        begin
            local=local[:prev]
            piece=Envir.get_by_mode(mode,:local,k,curElt) if (curElt=Envir.elt_defined?(local,keys,true))
	        end until piece or !(local[:prev])
	      end
	## special case : @mode==:post and @envir.local is the root
	      unless (mode==:post and (@local.include? :prev))
	  ## if piece is nil look in the global environment
	        piece=Envir.get_by_mode(mode,:global,k,curElt) if !piece and (curElt=Envir.elt_defined?(@global, keys,true))
	      end
	## if piece is nil the result is converted in latex in escape mode!!!
	      if piece.nil?
          return "" if emptyElt
	        return (escape ? '\\#'+@@start+k.gsub("_",'\_')+@@stop : w) 
	      else
	        return piece
	      end 
      end
    end

  end

end
