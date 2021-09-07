ifneq (,$(wildcard ./.env))
    include .env
    export
endif

theme-init:
	git clone git@github.com:RatanShreshtha/DeepThought.git themes/DeepThought

theme-update:
	cd themes/DeepThought && git pull origin main

dev:
	zola serve --interface 0.0.0.0 --port ${PORT}

.PHONY: theme-init theme-update dev
