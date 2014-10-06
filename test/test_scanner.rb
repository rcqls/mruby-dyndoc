require File.expand_path(File.join(File.dirname(__FILE__),'../mrblib/dyndoc/scanner.rb'))

d = Dyndoc::DevTagScanner.new :dtag

txt='{#document][#main][#>]toto[TOTO][#>]<<<\
	titééi #{toto}\
	[#?]#{+?toto}[#>]PLUS\
	[#?]#{=toto} == "TOTO"[#>]PLUS2\
	[#rb<]@tata="joe"\
[#nl][#>]tata is :{@tata}[#nl]\
{#case]:{@tata},#{toto},joe\
[#when]joe[#>]I am JOE\
[#when]TOTO[#>]I am Toto\
[#case}\
	>>>[#}'

#txt = '{#document][#main]titééééééi[#?]#{+?toto}[#>]PLUS[#}'

p txt
aa = d.process txt
p [:process,aa]

#vsc = Dyndoc::VarsScanner.new :vars
#p vsc
#p (vsc.build_vars("<<[tutu]<<[toto]"))
