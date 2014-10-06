module Dyndoc

  
  module MRuby


  #this is an attempt to offer an interface for running on a block tree.
  #usefull for user adding dtag.
  class BlckMngr

    attr_reader :children, :blck, :tmplMngr, :filter

    def initialize(tmplMngr,blck,tex,filter)
      @tmplMngr,@blck,@pos=tmplMngr,blck,0
      @tex,@filter=tex,filter
      @children=[] #the blocks
    end

    def parse_child(filter=@filter)
      @tmplMngr.parse(child,filter)
    end

    def parse(blck=@blck,filter=@filter)
      ##Dyndoc.warn  "parse!!!",blck
      res=@tmplMngr.parse(blck,filter)
      ##Dyndoc.warn "result parse",res
      res
    end

    def <<(content)
      @tex << content
      return self
    end

    def pos=(i)
      @pos=i
    end

    def pos
      @pos
    end

    def length
      @blck.length
    end

    def at_end?
      @pos == @blck.length-1
    end

    def next_at_end?
      @pos == @blck.length-2
    end

    def [](i)
      @blck[i]
    end

    def tag
      @blck[@pos]
    end

    def next_tag
      @blck[@pos+1]
    end

    def next_tag!
      @blck[@pos+=1]
    end

    def child(i=-1)
      @children[i]
    end

    def next_child_at(pos)
      b,i=[],pos
      while (i+1<@blck.length and @blck[i+1].is_a? Array)
        i+=1
        b << @blck[i]
      end
      return b
    end

    def next_child
      b=next_child_at(@pos)
      @gone=nil
      return b
    end

    def goto_next_child!
      unless @gone 
        @pos+=@children[-1].length 
        @gone=true #only once!
      end
    end

    def next_child!
      @children << next_child
      goto_next_child!
      return child
    end

    def next_child_until(tagset)
      b,i=[],@pos
      #p @blck
      while (i+1<@blck.length and !(tagset.include? @blck[i+1]))
       i += 1
       b << @blck[i]
      end
      @gone=nil
      return b
    end

    def next_child_until!(tagset)
      @children << next_child_until(tagset)
      goto_next_child!
      return child
    end

    def next_child_while(tagset)
      b,i=[],@pos
      while (i+1<@blck.length and (tagset.include? @blck[i+1]))
       i+=1
       b << @blck[i]
      end
      @gone=nil
      return b
    end

    def next_child_while!(tagset)
      @children << next_child_while(tagset)
      goto_next_child!
      return child
    end

    def child_as_var 
      b=@tmplMngr.make_var_block(child.unshift(:var),@filter)
      @tmplMngr.eval_VARS(b,@filter)
    end

  end

  class TemplateManager

    @@newBlcks={}

    def do_newBlck(tex,b,filter)
      blckMngr=BlckMngr.new(self,b,tex,filter)
      blckname=b[1][1].strip
      ##p blckname
      if ["saved"].include? blckname
        Dyndoc.warn "Warning: Impossible to redefine an existing instruction!"
      end
      #puts "new_blck:b";p b
      blckMngr.pos=1
      items=[]
      return unless [:blck,:aggregate].include? blckMngr.next_tag
      @@newBlcks[blckname]={}
      if blckMngr.next_tag==:aggregate
        blckMngr.next_tag!
        @@newBlcks[blckname][:aggregate]= blckMngr.next_tag![1].strip.split(",")
      end
      while blckMngr.next_tag! == :blck and !blckMngr.at_end?
        items << (item=blckMngr.next_tag![1].strip)
        blcks=[]
        while (blckMngr.next_tag != :blck) and !blckMngr.at_end?
          blcks << blckMngr.next_tag!
        end
        if [":pre",":post"].include? item
          @@newBlcks[blckname][item]=blcks
        else
          i,subBlcks=-1,{}
          while ([:pre,:post,:do_code].include? blcks[i+1]) and !(i==blcks.length-1)

            subname=blcks[i+=1]
            subBlcks[subname]=[]
            while !([:pre,:post,:do_code].include? blcks[i+1]) and !(i==blcks.length-1)
              subBlcks[subname] << blcks[i+=1]
            end
          end
          @@newBlcks[blckname][item]=subBlcks
        end

      end

      ## declare the new block!
      add_dtag({
      :instr=>[blckname],
      :keyword_reg=>{
        blckname.to_sym=> '[%.\w,><?=+:-]+'
      },
      :with_tagblck=>[blckname.to_sym],
      },"blck") #alias of blck!
#=begin
      (items-[":pre",":post"]).each do |item|
        #p @@newBlcks[blckname][item]

        if @@newBlcks[blckname][item][:do_code]
          blckRbCode=
%Q[def do_blck_#{blckname}_#{item}(tex,blck,filter)
##p blck
  blckMngr=BlckMngr.new(self,blck,tex,filter)
  ## the next code is automatically generated!
  #{@@newBlcks[blckname][item][:do_code][0][1]}
end]
          #p blckRbCode
          Dyndoc::V3::TemplateManager.module_eval(blckRbCode)
        end
      end
#=end
      #p methods.sort
      #puts "newBlck[\"#{blckname}\"]";p @@newBlcks[blckname]
    end

    def blckMode_normal?
      (@@newBlcks.keys & @blckDepth).empty?
    end

    def aggregate_newBlck(blck,aggrItems,allAggrItems,from)
      res,newBlck=blck[0...from],nil
      ##puts "debut aggr";p res;p aggrItems;p allAggrItems
      resAggr=[] #to save the different elements in the right order 
      (from..(blck.length-1)).each do |i|
        if newBlck
          if allAggrItems.include? blck[i]
            if aggrItems.include? blck[i]
              resAggr << (newBlck={:tag=>blck[i],:blck=>[:blck]})
            else
              newBlck = nil
              resAggr << blck[i]
            end
          else
            newBlck[:blck] << blck[i]          
          end
        else 
          if aggrItems.include? blck[i]
            resAggr << (newBlck={:tag=>blck[i],:blck=>[:blck]})
          else
            resAggr << blck[i]
          end
        end
      end

      ## if defaultFmtCotainer defined use it as block starter!
      start=@defaultFmtContainer ? @defaultFmtContainer : :>
      ##puts "start";p start
      #puts "resAggr";p resAggr
      resAggr.each {|e|
        if e.is_a? Hash
          res << e[:tag] << ((e[:blck][1].is_a? Symbol) ? e[:blck] : [:blck,start]+e[:blck][1..-1])
        else
          res << e
        end 
      }
      ##puts "result";p res
      res

    end

    def completed_newBlck(cmd,blckname,blck,filter)
      ### IMPORTANT: blckname==nil means inside sub-blck :blckAnyTag and then no init performed as :pre and :post preprocess!  
      ## As in [#rb>] for (i in 1..3) {#>][#bar]....[#} !!!! No blckname here!
      if blckname
        filter.envir["blckname"]=blckname
      end
      #puts "completed_newBlck: blck init";p blck
      i=(blckname ? 2 : 1)
      ## blckAnyTag behaves like the previous tag in @@newBlcks.keys (all the user-defined commands)
      cmd=@blckDepth.reverse.find{|e| @@newBlcks.keys.include? e} if cmd=="blckAnyTag"
#Dyndoc.warn "extension",[i,cmd,@@newBlcks[cmd],@blckDepth]
      items=(@@newBlcks[cmd].keys)-[":pre",":post",:aggregate]
      #puts "completed:items";p items
      if @@newBlcks[cmd][:aggregate] #and blckname
        ##puts "aggregate";
        blck=aggregate_newBlck(blck,@@newBlcks[cmd][:aggregate].map{|e| e.to_sym},items.map{|e| e.to_sym},i)
      end
      ## first replace :"," by :"=" 
      while blck[i]==:","
        blck[i]= :"="
        i+=2
      end
      ## prepend the pre code if it exists!
      if @@newBlcks[cmd][":pre"] and blckname
        blck.insert(i,*(@@newBlcks[cmd][":pre"]))
        i+=@@newBlcks[cmd][":pre"].length
      end
      while i < blck.length-1
        item=blck[i].to_s
        #puts "item";p cmd;p item
        if items.include? item
          if @@newBlcks[cmd][item][:pre]
            blck.insert(i,*(@@newBlcks[cmd][item][:pre]))
            i+=@@newBlcks[cmd][item][:pre].length
          end
          if @@newBlcks[cmd][item][:do_code] and blck[i+1].respond_to? "[]" and blck[i+1][0]==:named
            blck.insert(i,blck[i+1])
            blck.insert(i,:"=")
            i+=2
          elsif !@@newBlcks[cmd][item][:do_code]
            blck[i]=(blck[i+1][0]==:named ? :"=" : :">")
          end
          i+=2
          if @@newBlcks[cmd][item][:post]
            #puts "post";p blck[i-1];p blck[i];p blck[i+1];p *(@@newBlcks[cmd][item][:post])
            blck.insert(i,*(@@newBlcks[cmd][item][:post]))
            i+=@@newBlcks[cmd][item][:post].length
          end
        else
          i+=1
        end
        #puts "completed_newBlck: blck iter";p blck
      end
      #puts "completed_newBlck: blck before end";p blck
      ## prepend the pre code if it exists!
      if @@newBlcks[cmd][":post"] and blckname
        blck.insert(i+1,*(@@newBlcks[cmd][":post"]))
        i+=@@newBlcks[cmd][":post"].length
      end
      #p blck
      ## find tag
      #p @@newBlcks[cmd]
      #puts "completed_newBlck: blck end";p blck
      return blck
    end

  end

  end

end