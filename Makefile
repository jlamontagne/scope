.PHONY: install clean distclean build test serve watch watch-test lint

install:
	@npm install
	@$$(npm bin)/elm-package install --yes

clean:
	rm public/index.html

build: public/index.html

public/index.html: main.elm
	@[ -d $(dir $@) ] || (mkdir -p $(dir $@))
	@$$(npm bin)/elm-make main.elm --output=public/index.html

serve:
	@npm start

watch:
	@$$(npm bin)/nodemon -e "elm" --exec "make --ignore-errors -j build"

watch-test:
	@$$(npm bin)/nodemon -e "js" --exec "make --ignore-errors test"

lint:
	@$$(npm bin)/eslint .
	@echo "[lint] done"

test: build lint
	@$$(npm bin)/mocha
