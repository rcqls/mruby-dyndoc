#include "mruby.h"
#include "mruby/irep.h"
#include "mruby/proc.h"

int
main(void)
{
  /* new interpreter instance */
  mrb_state *mrb;
  mrb = mrb_open();

  /* read and execute compiled symbols */
  int n = mrb_read_irep(mrb, test_symbol);
  mrb_run(mrb, mrb_proc_new(mrb, mrb->irep[n]), mrb_top_self(mrb));

  mrb_close(mrb);

  return 0;
}