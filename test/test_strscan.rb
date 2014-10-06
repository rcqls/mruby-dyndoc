# need complete path
require File.expand_path(File.join(File.dirname(__FILE__),'../mrblib/dyndoc.rb'))

#s,r,r2="tototito",/tot/,/ti/
s,r,r2="{#document][#main]titééi[#}",/\{\#/,/(\]?)\s*(\[[\#\@]([\w\:\|-]*[<>]?[=?!><]?)\})/
a=DyndocStringScanner.new(s)

p (a.exist? r)

p [a.string,a.pos]

p "scan"

a.scan r

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

a.reset

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

a.pos=18

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

p "scan_until"

p (a.scan_until r2)

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

a.reset

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

p "check"

p (a.check r)

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

a.reset

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

p "check_until"

p (a.check_until r2)

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

a.reset

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

p "skip"

p (a.skip r)

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

a.reset

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

p "skip_until"

p (a.skip_until r2)

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]

a.reset

p [a.string,a.pos,a.rest,a.pre_match,a.matched,a.post_match]


# # txt = ""

# # txt += "toto"

# # p txt

# # p txt.byteslice 0,3

# # p txt.byteslice 0...3
