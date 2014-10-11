#include <stdio.h>
#include <string.h>

#include "mruby.h"
#include "mruby/compile.h"
#include "mruby/string.h"

char* mrb_load_string_cxt_to_cstr(mrb_state *mrb,char* code,mrbc_context *cxt) {
	mrb_value cmd;
	char* res;

	cmd = mrb_load_string_cxt(mrb,code,cxt);
	res=(char*)mrb_string_value_ptr(mrb,cmd);
	return res;
}

int mrb_init_dyndoc(mrb_state *mrb,mrbc_context *cxt) {

	mrb_value init;
	init = mrb_load_string_cxt(mrb,"unless $tmpl_mngr\n$tmpl_mngr = Dyndoc::MRuby::TemplateManager.new({})\n$tmpl_mngr.init_doc({})\nend",cxt);
	
	return (int)(!mrb_nil_p(init));
}

char* mrb_process_dyndoc(mrb_state *mrb, char* code,mrbc_context *cxt) {
	char* res, *cmd;

	cmd=(char*)mrb_malloc(mrb,(size_t)(strlen(code)+50));
	sprintf(cmd,"$tmpl_mngr.parse(%%q{%s})",code);
	//printf("code=%s\n",code);
	res = mrb_load_string_cxt_to_cstr(mrb,cmd,cxt);
	return res;
}

//for dyndoc mruby eval (since binding not offered yet!)
static mrb_state* dyndoc_mrb=NULL;
static mrbc_context* dyndoc_cxt=NULL;

mrb_value dyndoc_cxt_eval(mrb_state *mrb, mrb_value self) {
	char* code;
	mrb_int len;

	mrb_get_args(mrb, "s", &code, &len);
	//printf("code=<<%s>>\n",code);
	if(dyndoc_cxt == NULL) {
		//printf("new context!\n");
		dyndoc_mrb = mrb_open();
		dyndoc_cxt=mrbc_context_new(mrb);
	}
	return mrb_load_string_cxt(dyndoc_mrb,code,dyndoc_cxt);
}


void
mrb_mruby_dyndoc_gem_init(mrb_state* mrb)
{
	mrb_define_module_function(mrb, mrb->kernel_module, "dyndoc_cxt_eval", dyndoc_cxt_eval, MRB_ARGS_REQ(1));
}

void
mrb_mruby_dyndoc_gem_final(mrb_state* mrb)
{
	if(dyndoc_cxt != NULL) {
		mrbc_context_free(dyndoc_mrb,dyndoc_cxt);
	}
}

