ifneq (,$(wildcard ./.env))
    include .env
    export
endif

theme-init:
	git clone git@github.com:aaranxu/tale-zola.git themes/tale-zola

serve:
	zola serve --interface 0.0.0.0 --port 2000

.PHONY: theme-init serve
