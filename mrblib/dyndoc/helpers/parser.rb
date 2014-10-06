module Dyndoc;module MRuby;module Helpers


      # preprocessing for parsing a string
      # convert name to #{name!} in order to be executed! 
      def process_bang(str)
        str.gsub(/[#{FilterManager.letters}]*\:?[#{FilterManager.letters}]*\!/) {|e| "\#{" + e + "}"}
      end

      ## TODO: improve this by using lookbehind with Regepr
      def detect_string_inside_string(str)
        ary=str.split(/(\")/)
        inside,res=false,[""]
        ary.each_index do |cpt|
          if ary[cpt]=="\"" and cpt>0 and ary[cpt-1][-1,1]!="\\" #lookbehind 
            if inside
              res[-1] += "\"" #end of the previous string
              res << "" unless cpt == ary.length-1 #new string
            else
              res << "\"" #beginning of a string
            end
            inside = !inside
          else
            res[-1]+=ary[cpt]
          end
        end
        return res
      end

      def process_rb(str)
        part=detect_string_inside_string(str)
#p [:process_rb,part]
        part.each_index{|i|
          delim=(i%2==0 ? "\"" : "\\\"" ) #depending on inside or outside string!!!!
          part[i]=part[i].gsub(/<[\w\.\_\-]+\@>/) {|e| 
            "@vars.extract_raw(#{delim}"+e[1...-1]+"#{delim})[:rb]"
          }
          part[i]=part[i].gsub(/<([\w\.\_\-]+)((?:[\$\[][^>])+(?:(?!\$>).){0,500})?\$>/) {|e|
            var=$1+"$"
  #puts "process_rb:<var$>";p $1;p $2 
            if (arg=$2)
              #@vars.extract_raw(var)[:r].arg=arg
  #puts "arg";p arg;p @vars.extract_raw(var)[:r].value_with_arg
              "@vars.extract_raw(#{delim}"+var+"#{delim})[:r].set_arg(#{delim}"+arg+"#{delim}).value_with_arg"
            else
              "@vars.extract_raw(#{delim}"+var+"#{delim})[:r].value"
            end
          }

          part[i]=part[i].gsub(/<([\w\.\_\-]+)((?:[\&\[][^>])+(?:(?!\&>).){0,500})?\&>/) {|e|
            var=$1+"&"
  #puts "process_rb:<var$>";p $1;p $2 
            if (arg=$2)
              #@vars.extract_raw(var)[:r].arg=arg
  #puts "arg";p arg;p @vars.extract_raw(var)[:r].value_with_arg
              "@vars.extract_raw(#{delim}"+var+"#{delim})[:jl].set_arg(#{delim}"+arg+"#{delim}).value_with_arg"
            else
              "@vars.extract_raw(#{delim}"+var+"#{delim})[:jl].value"
            end
          }
#=end
          part[i]=part[i].gsub(/<[\w\.\_\-]+\:>/) {|e| 
            "@vars.extract_raw(#{delim}"+e[1...-2]+"#{delim})[:val][0]"
          }
          ## dynArray var
          part[i]=part[i].gsub(/<[\w\.\_\-]+\%>/) {|e|
            #p e[1...-1]
            #p @vars.extract_raw(e[1...-1])
            #@vars.extract_raw(e[1...-1])[:rb][0]-= 10
            #(Dyndoc::Vector.get[@vars.extract_raw(e[1...-1])[:rb].ids(:rb)])[0]=10
            @vars.extract_raw(e[1...-1])[:rb].wrapper(:rb)
          }

        }
        #-| TO DEBUG: Dyndoc.warn part.join("") if part.join("")!=str
#p part.join("")
        ####replaced: str.replace(part.join(""))
        return part.join("")
      end

# #=begin
#       def process_rb(str)
# #puts "str";p str       
#         str.gsub!(/<[\w\.\_\-]+\@>/) {|e| 
#           "@vars.extract_raw(\""+e[1...-1]+"\")[:rb]"
#         }
# #puts "str(suite)";p str
# #=begin
# #        str.gsub!(/<([\w\.\_\-]+)((?:[\@\[][^>])+(?:(?!\@>).)*)?\@>/) {|e| 
# #p $1;p $2
# #          arg = ( $2 ? ( $2[0,1]=="@" ? "."+$2[1..-1] : $2 ) : "" )
# #p arg
# #          "@vars.extract_raw(\""+$1+"@\")[:rb]"+arg
# #        }
# #=end
# #=begin
# #        str.gsub!(/<[\w\.\_\-]+\$>/) {|e| 
# #          "@vars.extract_raw(\""+e[1...-1]+"\")[:r].value"
# #        }
# #=end
# #=begin
#         str.gsub!(/<([\w\.\_\-]+)((?:[\$\[][^>])+(?:(?!\$>).){0,500})?\$>/) {|e|
#           var=$1+"$"
# #puts "process_rb:<var$>";p $1;p $2 
#           if (arg=$2)
#             #@vars.extract_raw(var)[:r].arg=arg
# #puts "arg";p arg;p @vars.extract_raw(var)[:r].value_with_arg
#             "@vars.extract_raw(\""+var+"\")[:r].set_arg(\""+arg+"\").value_with_arg"
#           else
#             "@vars.extract_raw(\""+var+"\")[:r].value"
#           end
#         }
# #=end
#         str.gsub!(/<[\w\.\_\-]+\:>/) {|e| 
#           "@vars.extract_raw(\""+e[1...-2]+"\")[:val][0]"
#         }
# #p str
#       end
#=end

      def process_r(str)
        #str.gsub!(/<[\w\.\_\-]+\@>/) {|e| 
        #  "dynVar[["+e[1...-2]+"]]"
        #} 
        str2=str.dup
        ## ruby var
        str.gsub!(/<([\w\.\_\-]+)(\@)?((?:[\@\[][^>])+(?:(?!\@>).){0,500})?\@>/) {|e| 
#puts "process_r: ("+$1+","+($2 ? $2 : "nil" )+","+($3 ? $3 : "nil")+")"
          if $3
            arg =( $3[0,1]=="@" ? "."+$3[1..-1] : $3 )
#p arg
#p "dynRbVar[\""+$1+"@\",\""+arg+"\"]"
            "dynVarWithArg[[\""+$1+"\",\""+arg+"\",mode=\"@\"]]"
          else
            "dynVar[["+$1+",mode=\"@\","+($2 ? "FALSE" : "TRUE")+"]]"
          end
        }
        ## Julia var
        str.gsub!(/<([\w\.\_\-]+)(\&)?((?:[\&\[][^>])+(?:(?!\&>).){0,500})?\&>/) {|e| 
#puts "process_r(jl): ("+$1+","+($2 ? $2 : "nil" )+","+($3 ? $3 : "nil")+")"
          if $3
            arg =( $3[0,1]=="&" ? "."+$3[1..-1] : $3 ) #TODO: try to apply
#p arg
#p "dynRbVar[\""+$1+"@\",\""+arg+"\"]"
            "dynVarWithArg[[\""+$1+"\",\""+arg+"\",mode=\"&\"]]"
          else
            "dynVar[["+$1+",mode=\"&\","+($2 ? "FALSE" : "FALSE")+"]]"
          end
        }
        ## R var
        str.gsub!(/<[\w\.\_\-]+\$>/) {|e| 
          ".dynStack$rb"+@vars.extract_raw(e[1...-1]).object_id.abs.to_s
        }
        ## dynArray var
        str.gsub!(/<[\w\.\_\-]+\%>/) {|e|
          #p e[1...-1]
          #p @vars.extract_raw(e[1...-1])
          @vars.extract_raw(e[1...-1])[:rb].wrapper(:r)
        }
        ## Dyndoc var
        str.gsub!(/<[\w\.\_\-]+\:>/) {|e| 
          "dynVar["+e[1...-2]+"]"
        }
        #-| TO DEBUG:  Dyndoc.warn str if str!=str2
      end

      def process_jl(str)
        str2=str.dup
        ## dynArray var
        str.gsub!(/<[\w\.\_\-]+\%>/) {|e|
          #p e[1...-1]
          #p @vars.extract_raw(e[1...-1])
          @vars.extract_raw(e[1...-1])[:rb].wrapper(:jl)
        }
        #-| TO DEBUG:  Dyndoc.warn str if str!=str2
      end

      def clean_block_without_bracket(code)
        #puts "initial code";p code
        if code[0][0]==:main and code[0][1] =~ /^\s*\[/ and code[-1][0]==:main and code[-1][1] =~ /\]\s*$/
          code[0][1].sub!(/^(\s*)(\[)/) {|e| $1}
          code[-1][1]=code[-1][1].reverse.sub(/^(\s*)(\])/) {|e| $1}.reverse
          #puts "cleaned code";p code
        end
        code
      end

end;end;end
