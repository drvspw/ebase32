BASEDIR = $(shell pwd)
APPNAME = $(shell basename $(BASEDIR))
REBAR = rebar3
ELVIS = $(BASEDIR)/elvis

LINTERS = elvis xref eunit

.PHONY: elvis

compile:
	$(REBAR) compile

eunit:
	$(REBAR) eunit

xref:
	$(REBAR) xref

dialyzer:
	$(REBAR) dialyzer

elvis:
	$(ELVIS) rock -c elvis.config

test: $(LINTERS)

console: test
	$(REBAR) shell

todo:
	$(REBAR) todo

clean:
	$(REBAR) clean
	rm -rf _build

test-coverage-report:
	$(REBAR) cover --verbose
