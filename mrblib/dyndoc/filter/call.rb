module CqlsDoc

  class CallFilter

######################
## Common useful part
######################
 
    def CallFilter.init(tmpl,calls,args,meths)
      @@tmpl,@@calls,@@args,@@meths=tmpl,calls,args,meths
    end

    def CallFilter.parseArgs(call,args,isMeth=nil)
      call2= (call[-1,1]=="!" ?  call[0...-1] : call) #TODO: pas de "!" à la fin normalement!
      names=@@args[call2].dup if @@args[call2]
      names=names[1..-1] if names and isMeth
#puts "parseArgs:call,args,names";p call2;p args; p names
      args.map!{|e|
            v,k,o,t=e.scan(/(:?)([#{FilterManager.letters}]*)\s*(=?>?)(.*)/).flatten
#p [v,k,o,t]
            if o=="=" ## name=value
              ":"+k.strip+"=>"+t 
          elsif v==":" and !o.empty? ## :name => value
              e
          elsif names and names.length==1 and names[0][-1,1]=="*"
               ":"+names[0]+"=>"+e
          elsif names ##no named with names
#puts "names";p call;p names; p e
              p "No enough named parameter!!!" if names.empty?
              ":"+(names.shift)+"=>"+e
           else ##no named witout names
              e
            end
      }
      args.map!{|e| e.split("\n")}.flatten!
#puts "parseArgs:args";p args
    end

    def CallFilter.isMeth?(call)
      @@meths.include? call
    end

    def CallFilter.argsMeth(call,b)
      meth_args_b=nil
      if @@meths.include? call
        meth_args_b=b[1..-1] #for the called method
        b=b[0,1]
      end
#puts "argsMeth";p call;p b;p meth_args_b
      return [b,meth_args_b]
    end

    def CallFilter.output(w,filter)
      if w[0,1]=="\\"
	w[1..-1]
      else
        call,args,rest=w.split(/\((.*)\)/)
#p call;p args;p rest
        if args
          call,args=call[2,call.length-2],args.split(/\||@/).map{|e| e.strip}
        else
          call,args=call[2,call.length-3],[]
        end
#puts "call,args";p call; p args
        args,meth_args=CallFilter.argsMeth(call,args)
#puts "call2,args,meth_args";p call;p args;p meth_args
        CallFilter.parseArgs(call,args)
#puts "call3,args";p call;p args
        res2=@@tmpl.eval_CALL(call,args,filter,meth_args)
#puts "res2";p res2
        res2
      end
    end

###########################
## Useful for old dyn! 
###########################

    #require 'strscan'
    @@scan=DyndocStringScanner.new("")
    @@start=/\\?@[\{\[]/;
    @@start2={"{"=>/\{/,"["=>/\[/}
    @@stop={"{"=>/\}@?/,"["=>/\]@?/}

    def CallFilter.token(txt)
      @@scan.string=txt
      @@scan.pos=0
      deb=nil
      while @@scan.scan_until(@@start)
##p @@scan.matched;p @@scan.matched.length
        m=@@scan.matched
        deb=@@scan.pos-(m.length)
      end
      return nil unless deb

      i=0
      m=m[-1,1]
      while (r0=@@scan.exist?(@@stop[m])) and (r1=@@scan.exist?(@@start2[m])) and (r1<r0)
        @@scan.scan_until(@@start2[m])
        i+=1
      end

      begin
        i-=1
        @@scan.scan_until(@@stop[m])
        fin=@@scan.pos - (@@scan.matched.length)
      end while i>=0
      return [deb,fin]
    end

    def CallFilter.filter(str,filter)
      res=str.dup
##p res
      deb=nil
      begin
        deb,fin=CallFilter.token(res)
        if deb
          ##p res[deb..fin]
          res[deb..fin]= CallFilter.output(res[deb..fin],filter)
        end
      end while deb
      res
    end

  end

end