#include <stdio.h>
#include <string.h>

#include "mruby.h"
#include "mruby/compile.h"
#include "mruby/string.h"

char* mrb_load_string_to_cstr(mrb_state *mrb,char* code) {
	mrb_value cmd;
	char* res;

	cmd = mrb_load_string(mrb,code);
	res=(char*)mrb_string_value_ptr(mrb,cmd);
	return res;
}

int mrb_init_dyndoc(mrb_state *mrb) {

	mrb_value init;
	init = mrb_load_string(mrb,"unless $tmpl_mngr\n$tmpl_mngr = Dyndoc::MRuby::TemplateManager.new({})\n$tmpl_mngr.init_doc({})\nend");
	
	return (int)(!mrb_nil_p(init));
}

char* mrb_process_dyndoc(mrb_state *mrb, char* code) {
	char* res, *cmd;

	cmd=(char*)mrb_malloc(mrb,(size_t)(strlen(code)+50));
	sprintf(cmd,"$tmpl_mngr.parse(%%q{%s})",code);
	//printf("code=%s\n",code);
	res = mrb_load_string_to_cstr(mrb,cmd);
	return res;
}

void
mrb_mruby_dyndoc_gem_init(mrb_state* mrb)
{
}

void
mrb_mruby_dyndoc_gem_final(mrb_state* mrb)
{
}

