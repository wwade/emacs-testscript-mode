;;; testscript-mode-tests.el --- Tests for testscript-mode -*- lexical-binding: t -*-

;;; Commentary:

;; ERT tests for testscript-mode.

;;; Code:

(require 'ert)
(require 'testscript-mode)

;;; Helper macros

(defmacro testscript-test-with-buffer (content &rest body)
  "Insert CONTENT into a temp buffer in `testscript-mode', then run BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,content)
     (testscript-mode)
     (font-lock-ensure)
     (goto-char (point-min))
     ,@body))

(defun testscript-test-face-at (pos)
  "Return the face at POS in the current buffer."
  (get-text-property pos 'face))

;;; Mode setup tests

(ert-deftest testscript-test-mode-is-derived-from-prog-mode ()
  "The mode should derive from `prog-mode'."
  (with-temp-buffer
    (testscript-mode)
    (should (derived-mode-p 'prog-mode))))

(ert-deftest testscript-test-mode-name ()
  "The mode should have a descriptive mode name."
  (with-temp-buffer
    (testscript-mode)
    (should (string= mode-name "Testscript"))))

(ert-deftest testscript-test-comment-syntax ()
  "Hash should be recognized as comment start."
  (with-temp-buffer
    (testscript-mode)
    (should (string= comment-start "# "))
    (should (string= comment-end ""))))

(ert-deftest testscript-test-auto-mode-alist-txtar ()
  "Files ending in .txtar should trigger `testscript-mode'."
  (should (assoc "\\.txtar\\'" auto-mode-alist)))

;;; Font-lock tests: comments

(ert-deftest testscript-test-fontlock-comment ()
  "Lines starting with # should get comment face."
  (testscript-test-with-buffer "# a comment\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-comment-delimiter-face))))

(ert-deftest testscript-test-fontlock-inline-comment ()
  "Inline # comments after commands should get comment face."
  (testscript-test-with-buffer "exec foo # trailing\n"
    (let ((hash-pos (1+ (string-match "#" "exec foo # trailing"))))
      (should (memq (testscript-test-face-at hash-pos)
                     '(font-lock-comment-face font-lock-comment-delimiter-face))))))

;;; Font-lock tests: built-in commands

(ert-deftest testscript-test-fontlock-exec-command ()
  "The exec command should be highlighted."
  (testscript-test-with-buffer "exec cat foo.txt\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-keyword-face))))

(ert-deftest testscript-test-fontlock-stdout-command ()
  "The stdout command should be highlighted."
  (testscript-test-with-buffer "stdout 'hello'\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-keyword-face))))

(ert-deftest testscript-test-fontlock-stderr-command ()
  "The stderr command should be highlighted."
  (testscript-test-with-buffer "stderr 'error'\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-keyword-face))))

(ert-deftest testscript-test-fontlock-env-command ()
  "The env command should be highlighted."
  (testscript-test-with-buffer "env HOME=/tmp\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-keyword-face))))

(ert-deftest testscript-test-fontlock-cmp-command ()
  "The cmp command should be highlighted."
  (testscript-test-with-buffer "cmp stdout expected.txt\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-keyword-face))))

(ert-deftest testscript-test-fontlock-various-commands ()
  "All built-in commands should be highlighted as keywords."
  (dolist (cmd '("cat" "cd" "chmod" "cmpenv" "cp" "echo" "exists"
                 "grep" "help" "mkdir" "mv" "replace" "rm" "skip"
                 "sleep" "stdin" "stop" "symlink" "unquote" "wait" "update"))
    (testscript-test-with-buffer (concat cmd " arg\n")
      (should (eq (testscript-test-face-at 1) 'font-lock-keyword-face)))))

;;; Font-lock tests: negation and optional prefixes

(ert-deftest testscript-test-fontlock-negation-prefix ()
  "The ! prefix should be highlighted."
  (testscript-test-with-buffer "! stderr .\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-negation-char-face))))

(ert-deftest testscript-test-fontlock-optional-prefix ()
  "The ? prefix should be highlighted."
  (testscript-test-with-buffer "? exec might-fail\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-negation-char-face))))

;;; Font-lock tests: condition guards

(ert-deftest testscript-test-fontlock-condition-guard ()
  "Condition guards like [linux] should be highlighted."
  (testscript-test-with-buffer "[linux] exec uname\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-preprocessor-face))))

(ert-deftest testscript-test-fontlock-negated-condition ()
  "Negated condition guards like [!windows] should be highlighted."
  (testscript-test-with-buffer "[!windows] skip\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-preprocessor-face))))

(ert-deftest testscript-test-fontlock-exec-condition ()
  "Condition guards like [exec:cat] should be highlighted."
  (testscript-test-with-buffer "[exec:cat] stop\n"
    (should (eq (testscript-test-face-at 1) 'font-lock-preprocessor-face))))

;;; Font-lock tests: environment variables

(ert-deftest testscript-test-fontlock-env-var ()
  "Environment variables like $HOME should be highlighted."
  (testscript-test-with-buffer "exec echo $HOME\n"
    (let ((pos (1+ (string-match "\\$HOME" "exec echo $HOME"))))
      (should (eq (testscript-test-face-at pos) 'font-lock-variable-name-face)))))

(ert-deftest testscript-test-fontlock-env-var-braces ()
  "Environment variables like ${HOME} should be highlighted."
  (testscript-test-with-buffer "exec echo ${HOME}\n"
    (let ((pos (1+ (string-match "\\${HOME}" "exec echo ${HOME}"))))
      (should (eq (testscript-test-face-at pos) 'font-lock-variable-name-face)))))

;;; Font-lock tests: single-quoted strings

(ert-deftest testscript-test-fontlock-single-quoted-string ()
  "Single-quoted strings should be highlighted."
  (testscript-test-with-buffer "stdout 'hello world'\n"
    (let ((pos (1+ (string-match "'" "stdout 'hello world'"))))
      (should (eq (testscript-test-face-at pos) 'font-lock-string-face)))))

;;; Font-lock tests: file markers

(ert-deftest testscript-test-fontlock-file-marker ()
  "File marker lines like -- file.txt -- should be highlighted."
  (testscript-test-with-buffer "-- hello.txt --\n"
    (should (eq (testscript-test-face-at 1) 'testscript-file-marker-face))))

(ert-deftest testscript-test-fontlock-file-marker-with-path ()
  "File markers with paths should be highlighted."
  (testscript-test-with-buffer "-- subdir/file.go --\n"
    (should (eq (testscript-test-face-at 1) 'testscript-file-marker-face))))

;;; Font-lock tests: no highlighting in file content sections

(ert-deftest testscript-test-fontlock-no-highlight-in-file-section ()
  "Commands inside file content sections should not be highlighted."
  (testscript-test-with-buffer "-- file.txt --\nexec should-not-highlight\n"
    (forward-line 1)
    (should-not (eq (testscript-test-face-at (point)) 'font-lock-keyword-face))))

;;; Font-lock tests: background operator

(ert-deftest testscript-test-fontlock-background-operator ()
  "The & background operator at end of line should be highlighted."
  (testscript-test-with-buffer "exec long-task &\n"
    (let ((pos (1+ (string-match "&" "exec long-task &"))))
      (should (eq (testscript-test-face-at pos) 'font-lock-type-face)))))

;;; Imenu tests

(ert-deftest testscript-test-imenu-indexes-files ()
  "Imenu should index file marker lines."
  (testscript-test-with-buffer
      "# script\nexec foo\n-- hello.txt --\ncontent\n-- other.go --\nmore\n"
    (let ((index (funcall imenu-create-index-function)))
      (should (= (length index) 2))
      (should (assoc "hello.txt" index))
      (should (assoc "other.go" index)))))

(ert-deftest testscript-test-imenu-indexes-paths ()
  "Imenu should index file markers that contain paths."
  (testscript-test-with-buffer
      "-- subdir/deep/file.go --\ncontent\n"
    (let ((index (funcall imenu-create-index-function)))
      (should (assoc "subdir/deep/file.go" index)))))

;;; Navigation tests

(ert-deftest testscript-test-next-file-section ()
  "Should navigate to the next file marker."
  (testscript-test-with-buffer
      "# script\nexec foo\n-- hello.txt --\ncontent\n-- other.go --\nmore\n"
    (goto-char (point-min))
    (testscript-next-file-section)
    (should (looking-at "-- hello\\.txt --"))
    (testscript-next-file-section)
    (should (looking-at "-- other\\.go --"))))

(ert-deftest testscript-test-previous-file-section ()
  "Should navigate to the previous file marker."
  (testscript-test-with-buffer
      "# script\nexec foo\n-- hello.txt --\ncontent\n-- other.go --\nmore\n"
    (goto-char (point-max))
    (testscript-previous-file-section)
    (should (looking-at "-- other\\.go --"))
    (testscript-previous-file-section)
    (should (looking-at "-- hello\\.txt --"))))

(ert-deftest testscript-test-next-file-section-wraps ()
  "Should signal an error when no more file sections."
  (testscript-test-with-buffer "# just script\nexec foo\n"
    (goto-char (point-min))
    (should-error (testscript-next-file-section) :type 'user-error)))

;;; Comment functionality tests

(ert-deftest testscript-test-comment-region ()
  "Commenting a region should insert # prefixes."
  (with-temp-buffer
    (testscript-mode)
    (insert "exec foo\nexec bar\n")
    (comment-region (point-min) (point-max))
    (goto-char (point-min))
    (should (looking-at "# exec foo"))))

(provide 'testscript-mode-tests)

;;; testscript-mode-tests.el ends here
