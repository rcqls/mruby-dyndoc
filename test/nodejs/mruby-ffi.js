var ref=require("ref");
var RefArray = require('ref-array');
var ffi=require("ffi");

var intPtr=ref.refType("int");
var voidPtr=ref.refType("void");
var doubleAry=RefArray("double");
//var VoidArray=RefArray("void");
var intAry=RefArray("int");
var stringAry=RefArray("string");

var mrbState='void', mrbStatePtr=ref.refType(mrbState);

var mrb_ffi=ffi.Library(process.env["MRB4FFI_LIB"] || "/Users/remy/devel/mruby/build/host/lib/libmruby",{
	"mrb_open":[mrbStatePtr,[]],
	"mrb_close":["void",[mrbStatePtr]],
	"mrb_load_string":["void",[mrbStatePtr,"string"]]
	//"mrb_eval":["int",["string","int"]],
	// "mrb_get_ary":[voidPtr,["string",intPtr,intPtr]],
	// "mrb_as_double_ary":[doubleAry,[voidPtr]],
	// "mrb_as_int_ary":[intAry,[voidPtr]],
	// "mrb_as_string_ary":[stringAry,[voidPtr]],
	// "mrb_set_ary":["void",["string","pointer","int","int"]]
})

//var intPtr=ref.refType(ref.types.int);

var txt="'{#document][#main][#>]toto[TOTO][#r<]a=\"titi\"[#>]\n\
	{#case]joe\n\
[#when]joe[#>]I am JOE\n\
[#when]TOTO[#>]I am Toto\n\
[#case}[#}'"

var txt="'{#document][#main][#>]toto[TOTO][#r<]a=\"joe\"[#>]<<<\n\
	titééi #{toto}\n\
	[#?]#{+?toto}[#>]PLUS\n\
	[#?]#{=toto} == \"TOTO\"[#>]PLUS2\n\
	[#rb<]@tata=\"joe\"\n\
[#nl][#>]tata is :{@tata}[#nl]\n\
{#case]:{@tata},#{toto},:r{a}\n\
[#when]joe[#>]I am JOE\n\
[#when]TOTO[#>]I am Toto\n\
[#case}\n\
[#>]{#rverb]rnorm(10)[#rverb}\n\
	>>>[#}'"

//var init=function() {
var mrb=mrb_ffi.mrb_open();
mrb_ffi.mrb_load_string(mrb,"$a='hello world!'");
mrb_ffi.mrb_load_string(mrb,"p $a");
mrb_ffi.mrb_load_string(mrb,"R4mrb.init");
mrb_ffi.mrb_load_string(mrb,"R4mrb << 'print(rnorm(10))'");
mrb_ffi.mrb_load_string(mrb,"$tmpl_mngr = Dyndoc::MRuby::TemplateManager.new({});$tmpl_mngr.init_doc({})");
mrb_ffi.mrb_load_string(mrb,"puts $tmpl_mngr.parse("+txt+")");
mrb_ffi.mrb_close(mrb);
//}

// var eval=function(cmd) {
// 	rffi.rffi_eval(cmd,1);
// }