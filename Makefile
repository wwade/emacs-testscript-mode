EMACS ?= emacs
BATCH = $(EMACS) --batch -Q

EL = testscript-mode.el
ELC = $(EL:.el=.elc)
TEST_EL = test/testscript-mode-tests.el

.PHONY: all test compile checkdoc package-lint clean check

all: check

check: compile test checkdoc

compile: $(ELC)

%.elc: %.el
	$(BATCH) -L . -f batch-byte-compile $<

test: compile
	$(BATCH) -L . -l $(TEST_EL) -f ert-run-tests-batch-and-exit

checkdoc:
	$(BATCH) --eval \
	  "(progn \
	     (require 'checkdoc) \
	     (let ((files '(\"$(EL)\"))) \
	       (dolist (f files) \
	         (with-current-buffer (find-file-noselect f) \
	           (let ((checkdoc-force-docstrings-flag nil)) \
	             (checkdoc-current-buffer t))))))"

package-lint:
	$(BATCH) \
	  --eval "(require 'package)" \
	  --eval "(package-initialize)" \
	  --eval "(require 'package-lint)" \
	  -f package-lint-batch-and-exit $(EL)

clean:
	rm -f $(ELC)
