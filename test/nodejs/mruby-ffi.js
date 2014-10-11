var ref=require("ref");
var ffi=require("ffi");

var mrbState='void', mrbStatePtr=ref.refType(mrbState);
var mrbCxt='void', mrbCxtPtr=ref.refType(mrbCxt);

var mrbValue = ref.refType("void"),mrbValuePtr=ref.refType(mrbValue);

var mrb_ffi=ffi.Library(process.env["MRB4FFI_LIB"] || "/Users/remy/devel/mruby/build/host/lib/libmruby",{
	"mrb_open":[mrbStatePtr,[]],
	"mrb_close":["void",[mrbStatePtr]],
	"mrbc_context_new":[mrbCxtPtr,[mrbStatePtr]],
	"mrb_load_string_cxt_to_cstr":["string",[mrbStatePtr,"string",mrbCxtPtr]],
	"mrb_init_dyndoc":["int",[mrbStatePtr,mrbCxtPtr]],
	"mrb_process_dyndoc":["string",[mrbStatePtr,"string",mrbCxtPtr]]
})

var txt="'{#document][#main][#>]toto[TOTO][#r<]a=\"titi\"[#>]\n\
	{#case]joe\n\
[#when]joe[#>]I am JOE\n\
[#when]TOTO[#>]I am Toto\n\
[#case}[#}'"

var txt="{#document][#main][#>]toto[TOTO][#r<]a=\"joe\"[#>]<<<\n\
	titééi #{toto}\n\
	[#?]#{+?toto}[#>]PLUS\n\
	[#?]#{=toto} == \"TOTO\"[#>]PLUS2\n\
	[#r>>]runif(2)[#rb<]@tata=\"joe\"\n\
[#nl][#>]tata is :{@tata}[#nl]\n\
{#case]:{@tata},#{toto},:r{a}\n\
[#when]joe[#>]I am JOE\n\
[#when]TOTO[#>]I am Toto\n\
[#case}\n\
[#>]{#rverb]rnorm(10)[#rverb}\n\
	>>>[#}"


var mrb = mrb_ffi.mrb_open();
var cxt = mrb_ffi.mrbc_context_new(mrb);

var res = mrb_ffi.mrb_load_string_cxt_to_cstr(mrb,"a='hello'",cxt);
//mrb_ffi.mrb_p(mrb,tmp);
//var klass = mrb_ffi.mrb_obj_classname(mrb,tmp);
//console.log("class:"+klass);
//var res = mrb_ffi.mrb_string_value_ptr(mrb,tmp.deref());
console.log("res:"+res);

var res = mrb_ffi.mrb_load_string_cxt_to_cstr(mrb,"a*2",cxt);
//mrb_ffi.mrb_p(mrb,tmp);
//var klass = mrb_ffi.mrb_obj_classname(mrb,tmp);
//console.log("class:"+klass);
//var res = mrb_ffi.mrb_string_value_ptr(mrb,tmp.deref());
console.log("res:"+res);

//var res = mrb_ffi.mrb_str_to_cstr(mrb,mrb_ffi.mrb_gv_get(mrb,mrb_ffi.mrb_intern_cstr(mrb,"$a")));
//mrb_ffi.mrb_load_string(mrb,"p $a");
//mrb_ffi.mrb_load_string(mrb,"R4mrb.init");
//mrb_ffi.mrb_load_string(mrb,"R4mrb << 'print(rnorm(10))'");
//mrb_ffi.mrb_load_string_to_cstr(mrb,"$tmpl_mngr = Dyndoc::MRuby::TemplateManager.new({});$tmpl_mngr.init_doc({})");
//var res=mrb_ffi.mrb_load_string_to_cstr(mrb,"$tmpl_mngr.parse("+txt+")");



// mrb_ffi.mrb_init_dyndoc(mrb);
// mrb_ffi.mrb_init_dyndoc(mrb); //no problem only initialized once!
// var res = mrb_ffi.mrb_process_dyndoc(mrb,txt);

// console.log("res:"+res);
// var res2 = mrb_ffi.mrb_process_dyndoc(mrb,txt);

// console.log("res2:"+res2);
mrb_ffi.mrb_close(mrb);
 