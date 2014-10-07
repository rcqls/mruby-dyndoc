#require File.join(File.dirname(__FILE__),"../mrblib/dyndoc.rb")

txt='{#document][#main][#>]toto[TOTO][#r<]a="joe"[#>]<<<
	titééi #{toto}
	[#?]#{+?toto}[#>]PLUS
	[#?]#{=toto} == "TOTO"[#>]PLUS2
	[#rb<]@tata="joe"
[#nl][#>]tata is :{@tata}[#nl]
{#case]:{@tata},#{toto},:r{a}
[#when]joe[#>]I am JOE
[#when]TOTO[#>]I am Toto
[#case}
[#>]{#rverb]rnorm(10)[#rverb}
	>>>[#}'

txt2='{#document][#main][#>]toto[TOTO][#r<]a="titi"[#>]
	{#case]joe
[#when]joe[#>]I am JOE
[#when]TOTO[#>]I am Toto
[#case}#r{a}[#}'

txt2='{#document][#main][#>]toto[TOTO][#r<]a="titi"[#>]
	{#case]joe
[#when]joe[#>]I am JOE
[#when]TOTO[#>]I am Toto
[#case}[#}'

mngr = Dyndoc::MRuby::TemplateManager.new({})
p mngr
mngr.init_doc({})

# Dyndoc::RServer.init_envir

# R4mrb << "print(.GlobalEnv$.env4dyn)"

# p Dyndoc::RServer.exist?("Global")

a=mngr.parse(txt)
# #puts ""
puts a
