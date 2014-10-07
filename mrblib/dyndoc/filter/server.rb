# coding: utf-8

module Dyndoc

    VERB={:tex=>{
              :begin=>"\\begin{Verbatim}[frame=leftline,fontfamily=tt,fontshape=n,numbers=left]",
              :end=>"\\end{Verbatim}"
            },
	  		:ttm=>{
              :begin=>"\\begin{verbatim}",
              :end=>"\\end{verbatim}"
            },
            :txtl=>{
              :begin=>"<pre><code style=\"color:yellow;background-color:black\">",
              :end=>"</code></pre>"
            },
            :tm=>{
              :begin=>"<\\verbatim>__TM__",
              :end=>"__TM__</verbatim>"
            },
            :raw=>{
            	:begin=>"",
              	:end=>""
            }
          }
    VERB[:html]=VERB[:txtl]

   class RbServer

    @@start="\\{";@@stop="\\}"

    def RbServer.filter(str,rbEnvir=nil)
      res=str.gsub(/\\?(?i:\#Rb|\#rb|\:Rb|\:rb|\:)#{@@start}[^#{@@stop}]+#{@@stop}/) {|w|  
	  if w[0,1]=="\\"
	    w[1..-1]
	  else
	    k=(w[1,2].downcase=="rb" ? w[4..-2] : w[2..-2]) #the key
#p "apply:Rb";p k;p w;p rbEnvir
            RbServer.output(k,rbEnvir,:error=> w)
	  end
	}
      res
    end

# #=begin
#     def RbServer.output(code,rbEnvir=nil,error="ERROR")
#       begin
# #puts "code";p code
# 	      out=eval(code,rbEnvir)
# #puts "out";p out
#       rescue
#         out=error
#       end
# #p out
#       out=out.join(",") if out.is_a? Array
#       out.to_s
#     end
# #=end

	Binding = Kernel

    def RbServer.output(code,rbEnvir=nil,opts={:error=>"ERROR"})
    	#Dyndoc.warn "output",[code,rbEnvir]
	    begin
	    	#p [:rbEnvir,rbEnvir,rbEnvir.nil?]
	    	if rbEnvir.is_a? Symbol
		    	#Dyndoc.warn [:nil]
		    	out = eval(code)
	        elsif rbEnvir.is_a? Binding
	        	#Dyndoc.warn [:Binding]
		    	out=rbEnvir.eval(code)
		    elsif rbEnvir.is_a? Module
		    	#Dyndoc.warn :Module
		        out=rbEnvir.module_eval(code)
		    else
		    	#Dyndoc.warn "ici"
		    	out=rbEnvir.instance_eval(code)
		    end

		    #Dyndoc.warn "out",out
	    rescue
	    	#Dyndoc.warn :rescue
	    	if RUBY_VERSION >= "1.9.3" and rbEnvir.is_a? Binding and rbEnvir.eval("local_variables").include? :childBinding 
	    		begin 
		    		rbEnvir2=rbEnvir.eval("childBinding")
		    		out=rbEnvir2.eval(code)
		    		return out
		    	rescue
		    	end
	    	end

			#two solution:
			#in the same spirit as #{}
			# out="\\:{"+code+"}"
			# or more informative for debugging!

			out="\\:{"+code+"}"
			#Dyndoc.warn "out2",out
			
			if $dyndoc_ruby_debug and !$dyndoc_ruby_debug==:expression
	        	Dyndoc.warn "WARNING: >>>>>>>>>>>>>>>>>>+\n"+opts[:error]+" in #{rbEnvir}:\n"+code+"\n<<<<<<<<<<<<<<<<<<" 
			end


			if $cfg_dyn and $cfg_dyn[:dyndoc_mode]!=:normal and $dyn_logger
				##p ["error ruby",code]
	        	$dyn_logger.write("\nERROR Ruby:\n"+code+"\n")
	        end
			
	    rescue SyntaxError
	        puts "RbServer syntax error in: "+code
	        raise SystemError if $cfg_dyn[:dyndoc_mode]==:normal and  $dyndoc_ruby_debug
	        if $cfg_dyn and $cfg_dyn[:dyndoc_mode]!=:normal
	        	$dyn_logger.write("\nERROR Ruby Syntax:\n"+code+"\n")
	        end
	        out=":{"+code+"}"
	    end
#Dyndoc.warn "outLast",out
      	out
    end

    def RbServer.capture(code,rbEnvir=nil)

    	require 'stringio'
		require 'ostruct'

		begin
		    # redirect output to StringIO objects
		    oldstdout,oldstderr=$stdout, $stderr
		    stdout, stderr = StringIO.new, StringIO.new
		    $stdout, $stderr = stdout, stderr

		    if rbEnvir.is_a? Binding
		    	out=rbEnvir.eval(code)
		    elsif rbEnvir.is_a? Module
		        out=rbEnvir.module_eval(code)
		    end
		ensure
		    # restore normal output
		    $stdout, $stderr = oldstdout,oldstderr
		end
	    {input: code, output: out.inspect, stdout: stdout.string, stderr: stderr.string}
  	end

    def RbServer.inputsAndOutputs(code,rbEnvir=nil)
    	#####disabled:
    	# require 'ripper'
    	# res = []
    	# input = ""
    	# code.each_line do |l|
    	# 	input += l
    	# 	if Ripper.sexp input
    	# 		res << RbServer.capture(input,rbEnvir)
    	# 		input = ""
    	# 	end
    	# end
    	# res
    end

    def RbServer.echo(code,rbEnvir=nil,prompt="ruby> ",tab=2)
		out=""
		res=RbServer.inputsAndOutputs(code,rbEnvir)
		## Dyndoc.warn "RbServer",res
		res.each do |cmd|
			## Dyndoc.warn "input",cmd
		 	out << prompt+ cmd[:input].split("\n").each_with_index.map{|e,i| i==0 ? e : " "*(prompt.length)+e}.join("\n").gsub(/\t/," "*tab)
			out << "\n"
			## Dyndoc.warn "output1",out
			out << cmd[:stdout]
			out << cmd[:output] || ""
			## Dyndoc.warn "output2",out
			out << cmd[:stderr] != ""  ? cmd[:stderr] : ""
			out << (cmd[:output]  ? "\n\n" : "")
			## Dyndoc.warn "output3",out
		end
		out
	end

	def RbServer.echo_verb(txt,mode,rbEnvir=nil)
		## Dyndoc.warn "echo_verb:txt",txt
		txtout=Dyndoc::RbServer.echo(txt.strip,rbEnvir).strip
		mode=:default unless Dyndoc::VERB.keys.include? mode
		header= (mode != :default) and txtout.length>0
		out=""
		out << Dyndoc::VERB[mode][:begin] << "\n" if header
		out << txtout
		out << "\n" << Dyndoc::VERB[mode][:end] << "\n" if header
		out
    end

  end

  class RServer

  	#require 'tempfile'

	def RServer.R4mrb
		R4mrb.init
	end

    def RServer.echo_verb(txt,mode,env="Global",opts={prompt: ""})
    	##Dyndoc.warn "echo_verb",txt,mode,env,opts
      	txtout=Dyndoc::RServer.echo(txt,env,opts[:prompt]).strip
      	##Dyndoc.warn "echo_verb:txtout",txtout
      	mode=:default unless Dyndoc::VERB.keys.include? mode
      	header= (mode!=:default) and txtout.length>0
      	out=""
      	out << Dyndoc::VERB[mode][:begin] << "\n" if header
      	out << txtout
      	out << "\n" << Dyndoc::VERB[mode][:end] << "\n" if header
      	##Dyndoc.warn "echo_verb:out",out
      	out
    end

    def RServer.echo(block,env="Global",prompt="")
    	Utils.clean_eol!(block)
      txtout=""
      optout=nil #options for the output
      hide=0
      passe=0
      opt = nil
      code="" 
      block.each_line{|l|
		l2=l.chomp
		##Dyndoc.warn "echo",l2.string_sub(" ","").split("|")[0]
		##inst=l2.delete(" ").split("|")[0] #not mruby no delete!
		inst=l2.string_sub(" ","").split("|")[0]
		if inst
		  inst=inst.split(":")
		  ## number of lines to apply
		  nb = 1 #default
		  nb=inst[1].to_i if inst.length>1
		  ## instr to exec
		  inst=inst[0].downcase
		else
		  inst="line"
		end
		## options
		opt=l2.split("|")
		if opt.length>1
		  opt2=opt[1..-1]
		  ## of the form key=value like Hash
		  opt2.map!{|elt| elt.split("=")}
		  opt={}
		  ##opt2.each{|elt| opt[elt[0].downcase.delete(" ")]=elt[1]}
		  opt2.each{|elt| opt[elt[0].downcase.string_sub(" ","")]=elt[1]}
		else
		  opt=nil
		end
		case inst
		when "line"
		  txtout << "\n"
		when "##!eval"
		  passe= nb.to_i #this is a copy
		when "##out"
		  optout=opt
		when "##hide"
		  hide = nb.to_i
		else
		  txtout << ( code.length==0 ? prompt+"> " : "+ ") << l2 << "\n" if hide==0
		  if passe==0 and l2[0,1]!="#"
		    ## redirect R output
		    code << l << "\n" ##ajout de "\n" grace à Pierre (le 15/12/05) pour bug: "1:10 #toto" -> pas de sortie car parse erreur n2!!!
			case @@mode
	        when :capture_normal	    
		        evalOk=(R4mrb <<  ".output<<-capture.output({"+RServer.code_envir(code,env)+"})")
	        when :capture_cqls
	        	evalOk=(R4mrb <<  ".output<<-capture.output.cqls({"+RServer.code_envir(code,env)+"})")
	        end

		    ##Dyndoc.warn "evalOk",code,evalOk
		    if evalOk  
		     txt=(@@out < '.output' ) ##.join("\n").split(/\n/)
		     code="" 
		    else
		      txt=@@out=R4mrb::Dyn[]
		    end 
		    if optout and optout.keys.include? "short"
		      short=optout["short"].split(",")
		      short[0]=short[0].to_i
		      short[2]=short[2].to_i
		      ## Dyndoc.warn "short",[short,txt]
		      (0...short[0]).each{|i| txtout << txt[i] << "\n"}
		      txtout << short[1] << "\n"
		      le = txt.length
		      ((le-short[2])...le).each{|i| txtout << txt[i] << "\n"}
		    else
		      txtout << txt.join("\n")
		      txtout += "\n" if @@out.length>0
		      ##txt.each{|l| txtout << l <<"\n"}
		    end
		  end
		  optout=nil 
		  hide -= 1 if hide>0
		  passe -=1 if passe>0
		end
      }
      return txtout
    end

    def RServer.echo_blocks(block,prompt={:normal=>'> ',:continue=>'+ '},env="Global")
      Utils.clean_eol(block)
      inputs,outputs=[],[]
      input,output="",""
      optout=nil #options for the output
      hide=0
      passe=0
      opt = nil
      code="" 
	  block.each_line{|l|
		l2=l.chomp
		##inst=l2.delete(" ").split("|")[0]
		inst=l2.string_sub(" ","").split("|")[0]
		if inst
	  inst=inst.split(":")
	  ## number of lines to apply
	  nb = 1 #default
	  nb=inst[1].to_i if inst.length>1
	  ## instr to exec
	  inst=inst[0].downcase
	else
	  inst="line"
	end
	## options
	opt=l2.split("|")
	if opt.length>1
	  opt2=opt[1..-1]
	  ## of the form key=value like Hash
	  opt2.map!{|elt| elt.split("=")}
	  opt={}
	  ##opt2.each{|elt| opt[elt[0].downcase.delete(" ")]=elt[1]}
	  opt2.each{|elt| opt[elt[0].downcase.string_sub(" ","")]=elt[1]}
	else
	  opt=nil
	end
	case inst
	when "##!eval"
	  passe= nb.to_i #this is a copy
	when "##out"
	  optout=opt
	when "##hide"
	  hide = nb.to_i
	else
	  if hide==0
	    input << ( code.length==0 ? prompt[:normal] : prompt[:continue]) if prompt
	    input <<  l2 << "\n"
	  end
	  if passe==0 and l2[0,1]!="#"
	    ## redirect R output
	    code << l << "\n" ##ajout de "\n" grace à Pierre (le 15/12/05) pour bug: "1:10 #toto" -> pas de sortie car parse erreur n2!!!
	    evalOk=(R4mrb <<  ".output<<-capture.output({"+RServer.code_envir(code,env)+"})")
	    if evalOk  
	     txt=(@@out < '.output' ) ##.join("\n").split(/\n/)
	     code="" 
	    else
	      txt=@@out=R4mrb::Dyn[]
	    end 
	    if optout and optout.keys.include? "short"
	      short=optout["short"].split(",")
	      short[0]=short[0].to_i
	      short[2]=short[2].to_i
	      (0...short[0]).each{|i| output << txt[i] << "\n"}
	      output << short[1] << "\n"
	      le = txt.length
	      ((le-short[2])...le).each{|i| output << txt[i] << "\n"}
	    else
	      output << txt.join("\n")
	      output += "\n" if @@out.length>0
	    end
	    inputs << input
	    outputs << output.gsub(/^[\n]*/,"")
	    input,output="",""
	  end
	  optout=nil 
	  hide -= 1 if hide>0
	  passe -=1 if passe>0
	end
      }
      return {:in=>inputs,:out=>outputs}
    end


    @@mode=:capture_cqls #or :capture_protected or capture_normal or capture_local
    
    def RServer.mode=(val)
      @@mode= val
    end
    
    def RServer.mode
      @@mode
    end

    @@device_cmd,@@device="png","png"
    
    def RServer.device(dev="pdf")
    	case dev
    	when "pdf"
      		@@device_cmd,@@device="pdf","pdf" #(%{capabilities()["cairo"]}.to_R ? "cairo_pdf" : "pdf"),"pdf"
    	when "png"
    		@@device_cmd,@@device="png","png"
    	end
    end
    
    #def RServer.input_semi_colon(block)
    #  block.map{|e| e.chomp!;((e.include? ";") ? (ee=e.split(";");["##!eval",e,"##hide:#{ee.length}"]+ee) : e )}.compact.join("\n")
    #end
    
    def RServer.inputsAndOutputs(block,id="",optRDevice="",prompt={:normal=>'',:continue=>''},env="Global")
      Utils.clean_eol(block)
      envLoc=env
      optRDevice=(@@device=="png" ? "width=10,height=10,units=\"cm\",res=128" : "width=5,height=5,onefile=FALSE") if optRDevice.empty?
      R4mrb << "require(dyndoc)" if @@mode==:capture_cqls
      results=[]
      input,output="",""
      optout,optpasse=nil,nil #options for the output
      hide,passe,passeNb=0,0,0
      echo,echoLines=0,[]
      opt = nil
      code=""
      # add R device
      imgdir=($dyn_rsrc ? File.join($dyn_rsrc,"img") : "/tmp/Rserver-img"+rand(1000000).to_s)
      
      imgfile=File.join(imgdir,"tmpImgFile"+id.to_s+"-")
      cptImg=0
      imgCopy=[]

      FileUtils.mkdir_p imgdir unless File.directory? imgdir
      Dir[imgfile+"*"].each{|f| FileUtils.rm_f(f)}
#p Dir[imgfile+"*"]

	
	#Dyndoc.warn "fig command:", "#{@@device_cmd}(\"#{imgfile}%d.#{@@device}\",#{optRDevice})"
      R4mrb << "#{@@device_cmd}(\"#{imgfile}%d.#{@@device}\",#{optRDevice})"
      #block=RServer.input_semi_colon(block)
      # the following  is equivalent to each_line!
      block.each_line{|l|
	      l2=l.chomp
	      #Dyndoc.warn :l2,l2
	      ##inst=l2.delete(" ").split("|")[0]
	      inst=l2.string_sub(" ","").split("|")[0]
	      #Dyndoc.warn "inst",inst
	      if inst and inst[0,2]=="##"
	        #if inst
	          inst=inst.split(":")
	          ## number of lines to apply
	          nb = 1 #default
	          nb=inst[1].to_i if inst.length>1
	          ## instr to exec
	          inst=inst[0].downcase
	        #else
	        #  inst="line"
	        #end
	        ## options
	        opt=l2.split("|")
	        if opt.length>1
	          opt2=opt[1..-1]
	          ## of the form key=value like Hash
	          opt2.map!{|elt| elt.split("=")}
	          #p opt2
	          opt={}
	          ##opt2.each{|elt| opt[elt[0].downcase.delete(" ")]=elt[1..-1].join("=")}
	          opt2.each{|elt| opt[elt[0].downcase.string_sub(" ","")]=elt[1..-1].join("=")}
	        else
	          opt=nil
	        end
	        #Dyndoc.warn "opt",opt
	      else
	        inst="line"
	        opt=nil
	      end

        if echo>0
          echo -= 1
          echoLines << l2 
          next
        end
  
        if echo==0 and !echoLines.empty? and !results.empty?
          results[-1][:output] << "\n" unless results[-1][:output].empty?
          results[-1][:output]  << echoLines.join("\n")
          echoLines=[]
	      end

#Dyndoc.warn :inst, inst
	      case inst
	      when "##echo" ##need to be added
	        echo=nb.to_i
	      when "##!eval"
	        passe= nb.to_i #this is a copy
          	passeNb=nb.to_i #to remember the original nb
	        optpasse=opt
	      when "##out"
	        optout=opt
	      when "##hide"
	        hide = nb.to_i
	        #Dyndoc.warn :hide,hide
	      when "##fig"
	        if opt and opt["img"] and !opt["img"].empty?
	          imgName=File.basename(opt["img"].strip,".*")
	          imgName+=".#{@@device}" #unless imgName=~/\.#{@@device}$/
	          imgName=File.join(imgdir,imgName)
	          
	          imgCopy << {:in => imgfile+cptImg.to_s+".#{@@device}",:out=>imgName}
	          ##opt.delete("img")
	          opt.string_sub("img","")
	        else
	          imgName=imgfile+cptImg.to_s+".#{@@device}"
	        end
	        puts "DYN ERROR!!! no fig allowed after empty R output!!!" unless results[-1]
	        results[-1][:img]={:name=>imgName}
	        results[-1][:img][:opt]=opt if opt and !opt.empty? 
	        #could not copy file now!!!!
	      when "##add"
	        results[-1][:add]=opt
	      else
	      	#Dyndoc.warn :hide?, [hide,passe,@@mode]
	        if hide==0
	          promptMode=(code.length==0 ? :normal : :continue )
	          input << prompt[promptMode] if prompt
	          #puts "before";p l;p envLoc
	          l2,envLoc=RServer.find_envir(l2,envLoc)
	          #Dyndoc.warn "after",l,envLoc
	          input <<  l2 << "\n"
	          #Dyndoc.warn :input3, input 
	        end
	        if passe==0 and l2[0,1]!="#"
	          ## redirect R output
	          code << l2 << "\n" ##ajout de "\n" grace à Pierre (le 15/12/05) pour bug: "1:10 #toto" -> pas de sortie car parse erreur n2!!!
	          case @@mode
	          when :capture_cqls
	            ##TODO: instead of only splitting check that there is no 
	            ## or ask the user to use another character instead of ";" printed as is in the input! 
	            codes=code.split(";")
	            #Dyndoc.warn :codes, codes
	            evalOk=(R4mrb << ".output <<- ''")
	            codes.each{|cod|
	              evalOk &= (R4mrb <<  (tmp=".output <<- c(.output,capture.output.cqls({"+RServer.code_envir(cod,envLoc)+"}))"))
	              #Dyndoc.warn "tmp",tmp
	            }
              when :capture_protected
	            ##TODO: instead of only splitting check that there is no 
	            ## or ask the user to use another character instead of ";" printed as is in the input! 
	            codes=code.split(";")
	            evalOk=(R4mrb << ".output <<- ''")
	            codes.each{|cod|
	              evalOk &= (R4mrb <<  (tmp=".output <<- c(.output,capture.output.protected({"+RServer.code_envir(cod,envLoc)+"}))"))
	              #Dyndoc.warn "tmp",tmp
	            }
	          when :capture_normal
	            codes=code.split(";")
	            evalOk=(R4mrb << ".output <<- ''")
	            codes.each{|cod|
	              evalOk &= (R4mrb <<  (tmp=".output <<- c(.output,capture.output({"+RServer.code_envir(cod,envLoc)+"}))"))
	            }
	          when :sink #Ne marche pas à cause du sink!!!
	            evalOk=(R4mrb << (tmp=%{
	              zz <- textConnection(".output", "w")
	              sink(zz)
	              local({
	                #{code}
	              },.GlobalEnv$.env4dyn$#{envLoc}
	              )
                sink()
                close(zz)
                print(.output)
                }))
                #Dyndoc.warn "tmp",tmp
              when :capture_local
                codes=code.split(";")
                evalOk=(R4mrb << ".output <<- ''")
	            codes.each{|cod|
                cod=".output <<- c(.output,capture.output({local({"+cod+"},.GlobalEnv$.env4dyn$#{envLoc})}))"
                #Dyndoc.warn cod
	              evalOk &= (R4mrb << cod )
	            }
	          end
	          cptImg += 1 if File.exists? imgfile+(cptImg+1).to_s+".#{@@device}"
	          #p evalOk;p code;R4mrb << "print(geterrmessage())";R4mrb << "if(exists(\".output\") ) print(.output)"
	          if evalOk
	            txt=(@@out < '.output' ) ##.join("\n").split(/\n/)
	            code="" 
	          else
	            txt=@@out=[]
	          end 
	          if optout and optout.keys.include? "short"
	            short=optout["short"].split(",")
	            short[0]=short[0].to_i
	            short[2]=short[2].to_i
	            (0...short[0]).each{|i| output << txt[i] << "\n"}
	            output << short[1] << "\n"
	            le = txt.length
	            ((le-short[2])...le).each{|i| output << txt[i] << "\n"}
	          else
	            output << txt.join("\n")
	            output += "\n" if @@out.length>0
	          end
	          #Dyndoc.warn :inputAndOutput,[input,output]

	          input=RServer.formatInput(input).force_encoding("utf-8")
	          #Dyndoc.warn :input,[input,output]
	          output=RServer.formatOutput(output).force_encoding("utf-8")
	          #Dyndoc.warn :output2,[input,output]
	          #Dyndoc.warn :state, {:hide=>hide,:passe=>passe}
	          #if hide==0
	            result={}
	            result[:input]= (hide==0 ? input : "")
	            result[:prompt]= (hide==0 ? promptMode : :none)
	            result[:output]=output.gsub(/^[\n]*/,"")
	            results << result unless (result[:input]+result[:output]).empty?
	          #end
	          input,output="",""
	          
	        end
	        if passe==0 and l2[0,1]=="#"
	          result={}
	          result[:input]=RServer.formatInput(input).force_encoding("utf-8")
	          result[:prompt]=promptMode
	          result[:output]=""
	          results << result
	          input,output="",""
	        end
	        if passe>=1
	          result={}
	          result[:input]=RServer.formatInput(input).force_encoding("utf-8")
	          result[:prompt]= ( passe == passeNb ? :normal : :continue )#promptMode
	          result[:output]= ((optpasse and optpasse["print"]) ? optpasse["print"] : output)
	          #Dyndoc.warn :result,result
	          results << result
	          input,output="",""
	        end
	        optout=nil 
	        hide -= 1 if hide>0
	        passe -=1 if passe>0
	        #Dyndoc.warn :hide2,hide
	      end
      }
      R4mrb << "dev.off()"
      imgCopy.each{|e|
	      FileUtils.mkdir_p File.dirname(e[:out]) unless File.exist? File.dirname(e[:out])
	      if File.exists? e[:in] 
	        FileUtils.mv(e[:in],e[:out])
	      else
	        Dyndoc.warn "WARNING! #{e[:in]} does not exists for #{e[:out]}"
	        Dyndoc.warn "RServer:imgCopy",imgCopy
          	Dyndoc.warn "imgDir",Dir[imgdir+"/*"]
	      end
      }
      #TODO: remove all the file newly created!
      #Dyndoc.warn :results, results
      return results
    end
 
    @@out=R4mrb::Dyn[]

    @@start,@@stop="\\{","\\}"

    def RServer.formatOutput(out)
      #out2=out.gsub(/\\n/,'\textbackslash{n}')
      out.gsub("{",'\{').gsub("}",'\}').gsub("~",'\boldmath\ensuremath{\mathtt{\sim}}')
    end
    
    def RServer.formatInput(out)
      out2=out.gsub(/\\n/,'\textbackslash{n}')
      ## {\texttildelow}
      # unless out2=~/\\\w*\{.*\}/
      #   out2.gsub("{",'\{').gsub("}",'\}')
      # else
      #   out2
      # end
      #Dyndoc.warn :formatInput, [out,out2]
      out2,out3=out2.split("#") unless out2.empty?
      #Dyndoc.warn :formatInput2, [out,out2,out3]
      out2=out2.gsub(/(?<!\\textbackslash)\{/,'\{').gsub(/(?<!\\textbackslash\{n)\}/,'\}')
      #Dyndoc.warn :formatInput3, [out,out2]
      out2=out2+"#"+out3 if out3
      #Dyndoc.warn :formatInput4, [out,out2,out3]
      return out2.gsub("~",'\boldmath\ensuremath{\mathtt{\sim}}')
    end
    

    def RServer.filter(str)
      ## modified (28/5/04) (old : /\#R\{.+\}/ => {\#R{ok}} does not work since "ok}" was selected !!
      res=str.gsub(/\\?(?i:\#|\:)[rR]#{@@start}[^#{@@stop}]+#{@@stop}/) {|w|
	      if w[0,1]=="\\"
	        w[1..-1]
	      else
	        code=w[3..-2] #the key
          RServer.output(code,w[1,1]=="r")
	      end
      }
      res
    end

    def RServer.init_envir
    	##Dyndoc.warn "Rserver.init_envir!!!",Rserve.client
      	"if(!exists(\".env4dyn\",envir=.GlobalEnv)) {.GlobalEnv$.env4dyn<-new.env(parent=.GlobalEnv);.GlobalEnv$.env4dyn$Global<-.GlobalEnv}".to_R
    	##Dyndoc.warn "Global?",RServer.exist?("Global")
	end

    def RServer.exist?(env)
#puts "Rserver.exist? .env4dyn"
#"print(ls(.GlobalEnv$.env4dyn))".to_R
      "\"#{env}\" %in% ls(.GlobalEnv$.env4dyn)".to_R
    end

    def RServer.new_envir(env,parent="Global")
#puts "New env #{env} in #{parent}"
      ".GlobalEnv$.env4dyn$#{env}<-new.env(parent=.GlobalEnv$.env4dyn$#{parent})".to_R
    end
    
    def RServer.local_code_envir(code,env="Global")
      "local({"+code+"},.GlobalEnv$.env4dyn$#{env})"
    end

    def RServer.code_envir(code,env="Global")
      "evalq({"+code+"},.GlobalEnv$.env4dyn$#{env})"
    end

    def RServer.eval_envir(code,env="Global")
      #R4mrb << "evalq({"+code+"},.GlobalEnv$.env4dyn$#{env})" ##-> replaced by
      R4mrb << RServer.code_envir(code,env)
    end

    def RServer.find_envir(code,env)
#p code
#p env
      codeSaved=code.clone
      code2=code.split(/(\s*[\w\.\_]*\s*:)/)
#p code2
      if code2[0] and code2[0].empty?
        env=code2[1][0...-1].strip
        code=code2[2..-1].join("")
      end
      env2=env.clone
      #p [:find_envir,env,code]
      env=Dyndoc.vars[env+".Renvir"] unless RServer.exist?(env)
      unless RServer.exist?(env)
        puts "Warning! environment #{env2} does not exist!"
        code=codeSaved
        env="Global"
      end
      return [code,env]
    end

    def RServer.output(code,env="Global",pretty=nil)
      	code,env=RServer.find_envir(code,env)
      	code="{"+code+"}"
#Dyndoc.warn "RServer.output",code
#Dyndoc.warn "without",code,(@@out < "evalq("+code+",.env4dyn$"+env+")"),"done"
      	code="prettyNum("+code+")" if pretty
#Dyndoc.warn "with",code,(@@out < "evalq("+code+",.env4dyn$"+env+")"),"done"
		
      	## code="evalq("+code+",envir=.GlobalEnv$.env4dyn$"+env+")" ##-> replaced by
      	code=RServer.code_envir(code,env)
#Dyndoc.warn "RServer.output->",code,(@@out < code)
      	(@@out < code) #.join(', ')
    end

    def RServer.safe_output(code,env="Global",opts={}) #pretty=nil,capture=nil)
#Dyndoc.warn "opts",opts
      	code,env=RServer.find_envir(code,env)
      	invisible=code.split("\n")[-1].strip =~ /^print\s*\(/
      	code="{"+code+"}"
#Dyndoc.warn "RServer.safe_output",code
#Dyndoc.warn "without",code,(@@out < "evalq("+code+",.env4dyn$"+env+")"),"done"
      	code="prettyNum("+code+")" if opts[:pretty]
#Dyndoc.warn "with",code,(@@out < "evalq("+code+",.env4dyn$"+env+")"),"done"
		
      	## code="evalq("+code+",envir=.GlobalEnv$.env4dyn$"+env+")" ##-> replaced by
      	code=RServer.code_envir(code,env)
#Dyndoc.warn "RServer.output->",code,(@@out < code)
#Dyndoc.warn "RServer.safe_output: opts",opts,code,@@out.inspect
		if opts[:capture] or opts[:blockR]
			## IMPORTANT; this is here to ensure that a double output is avoided at the end if the last instruction is a print 
			code = "invisible("+code+")" if invisible
			code+=";invisible()" if opts[:blockR]
			#Dyndoc.warn "safe_output",code
			res=(@@out < "capture.output.cqls({"+code+"})")
			#Dyndoc.warn "res", res
			res=res.join("\n")
		else
#Dyndoc.warn "RServer.safe_output: res",res			
      		res=(@@out < "{.result_try_code<-try({"+code+"},silent=TRUE);if(inherits(.result_try_code,'try-error')) 'try-error' else .result_try_code}") #.join(', ')
 		end
#Dyndoc.warn "RServer.safe_output: res",res		
      	res 
    end

    #more useful than echo_tex!!!
    def RServer.rout(code,env="Global") 
      	out="> "+code
      	code="capture.output({"+code+"})"
      	## code="evalq("+code+",.GlobalEnv$.env4dyn$"+env+")" ##-> replaced by
		code=RServer.code_envir(code,env)
		#puts "Rserver.rout";p code
      	return (@@out< code).join("\n")
    end

    def RServer.init_filter
    	dyndocTools="~/dyndoc" #Same as DYNDOCROOT as default
    	# DYNDOCTOOLS is defined inside the launcher of DyndocStudio (Mac and linux).
    	dyndocTools=ENV["DYNDOCTOOLS"] if ENV["DYNDOCTOOLS"] and File.exists? ENV["DYNDOCTOOLS"]
    	## if RUBY_ENGINE (ruby,jruby,rbx) defined (actually, not defined for 1.8.7)
    	if Object.constants.map{|e| e.to_s}.include? "RUBY_ENGINE"
    		R4mrb << ".libPaths('"+dyndocTools+"/R/library/"+RUBY_ENGINE+"/"+RUBY_VERSION+"')"
    	end
      	R4mrb << "require(dyndoc)"
      	R4mrb << "require(rb4R)"
    end

  end

 #  class JLServer

 # 	# def JLServer.init(mode=:default) #mode=maybe zmq (to investigate) 
	# # 	require 'jl4rb'
	# # 	Julia.init
	# # end
	# @@initVerb=nil

	# def JLServer.initVerb
	# 	Julia << "include(\""+File.join($dyn_gem_root,"share","julia","dyndoc.jl")+"\")"
	# 	@@initVerb=true
	# end

	# def JLServer.inputsAndOutputs(code,hash=true)
	# 	JLServer.initVerb unless @@initVerb
	# 	res=(Julia << 'capture_julia('+code.strip.inspect+')')
	# 	## Dyndoc.warn "JLServer.inputsAndOutputs",res
	# 	res.map!{|input,output,output2,error,error2|
	# 		{:input=>input,:output=>output,:output2=>output2,:error=>error,:error2=>error2}
	# 	} if hash
	# 	res
	# end

	# def JLServer.eval(code)
	# 	Julia.eval(code)
	# end

	# def JLServer.output(code,opts={})
	# 	opts={:print=>true}.merge(opts)
	# 	## Dyndoc.warn "jlserv",code+"|"+Julia.eval(code,:print=>opts[:print]).to_s
	# 	Julia.eval(code,:print=>opts[:print]).to_s
	# end

	# def JLServer.outputs(code,opts={}) #may have more than one lines in code
	# 	## Dyndoc.warn "JLServer.outputs opts",opts
	# 	## Dyndoc.warn "JLServer code",code
	# 	if opts[:block]
	# 		res=JLServer.inputsAndOutputs(code,false)
	# 		return "" unless res
	# 		res.map{|input,output,output2,error,error2|
	# 			## Dyndoc.warn "output2",output2
	# 			output2
	# 		}.join("\n")
	# 	else
	# 		JLServer.eval(code)
	# 	end
	# end

	# def JLServer.echo(code,prompt="julia> ",tab=2)
	# 	out=""
	# 	res=JLServer.inputsAndOutputs(code)
	# 	## Dyndoc.warn "JLServer",res
	# 	res.each do |cmd|
	# 		## Dyndoc.warn "input",cmd
	# 	 	out << prompt+ cmd[:input].split("\n").each_with_index.map{|e,i| i==0 ? e : " "*(prompt.length)+e}.join("\n").gsub(/\t/," "*tab)
	# 		out << "\n"
	# 		## Dyndoc.warn "output1",out
	# 		out << cmd[:output2]
	# 		out << (cmd[:output]=="nothing"  ? "" : cmd[:output])
	# 		## Dyndoc.warn "output2",out
	# 		out << cmd[:error]!=""  ? cmd[:error] : ""
	# 		out << (cmd[:output]=="nothing"  ? "" : "\n\n")
	# 		## Dyndoc.warn "output3",out
	# 	end
	# 	out
	# end

	# def JLServer.echo_verb(txt,mode)
 #      txtout=Dyndoc::JLServer.echo(txt).strip
 #      mode=:default unless Dyndoc::VERB.keys.include? mode
 #      header= (mode!=:default) and txtout.length>0
 #      out=""
 #      out << Dyndoc::VERB[mode][:begin] << "\n" if header
 #      out << txtout
 #      out << "\n" << Dyndoc::VERB[mode][:end] << "\n" if header
 #      out
 #    end

 #  end

end
