;;; testscript-mode.el --- Major mode for editing testscript/txtar files -*- lexical-binding: t -*-

;; Copyright (C) 2026 Wade Carpenter

;; Author: Wade Carpenter
;; Assisted-by: Claude:claude-opus-4-6
;; Maintainer: Wade Carpenter
;; URL: https://github.com/wwade/emacs-testscript-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A major mode for editing testscript files that use the txtar archive
;; format, as used by Go's testscript testing framework
;; (https://github.com/rogpeppe/go-internal/tree/master/testscript).
;;
;; Testscript files contain a script section (shell-like commands) followed
;; by zero or more embedded file sections delimited by `-- FILENAME --'
;; markers.
;;
;; Features:
;; - Syntax highlighting for commands, conditions, comments, file markers
;; - Imenu support for navigating between embedded files
;; - Navigation commands for moving between file sections
;;
;; Usage:
;;   (require 'testscript-mode)
;;
;; The mode is automatically activated for .txtar files.

;;; Code:

(defgroup testscript nil
  "Major mode for editing testscript/txtar files."
  :group 'languages
  :prefix "testscript-")

(defface testscript-file-marker-face
  '((t :inherit font-lock-doc-face))
  "Face for txtar file marker lines (-- FILENAME --)."
  :group 'testscript)

(defconst testscript-file-marker-re
  "^-- .+ --$"
  "Regexp matching a txtar file marker line.")

(defconst testscript-builtin-commands
  '("cat" "cd" "chmod" "cmp" "cmpenv" "cp" "echo" "env" "exec"
    "exists" "grep" "help" "mkdir" "mv" "replace" "rm" "skip"
    "sleep" "stderr" "stdin" "stdout" "stop" "symlink" "unquote"
    "update" "wait")
  "List of built-in testscript commands.")

(defconst testscript-command-re
  (concat "^\\(?:\\[!?[^]]+\\]\\s-*\\)*"
          "\\(?:[!?]\\s-+\\)?"
          "\\(" (regexp-opt testscript-builtin-commands 'words) "\\)")
  "Regexp matching a testscript command at the start of a line.
Handles optional condition guards and negation/optional prefixes.")

(defvar testscript-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?# "<" st)
    (modify-syntax-entry ?\n ">" st)
    (modify-syntax-entry ?' "\"" st)
    (modify-syntax-entry ?$ "'" st)
    (modify-syntax-entry ?_ "w" st)
    st)
  "Syntax table for `testscript-mode'.")

(defun testscript--file-section-p (pos)
  "Return non-nil if POS is within a file content section.
A file content section is any text after a `-- FILENAME --' marker
up to the next marker or end of buffer."
  (save-excursion
    (goto-char pos)
    (beginning-of-line)
    (and (not (looking-at testscript-file-marker-re))
         (save-excursion
           (let ((found nil))
             (while (and (not found) (= (forward-line -1) 0))
               (when (looking-at testscript-file-marker-re)
                 (setq found t)))
             found)))))

(defun testscript--match-in-script (regexp limit)
  "Search for REGEXP up to LIMIT, skipping file content sections."
  (let ((found nil))
    (while (and (not found) (re-search-forward regexp limit t))
      (unless (testscript--file-section-p (match-beginning 0))
        (setq found t)))
    found))

(defun testscript--match-command (limit)
  "Font-lock matcher for built-in commands, up to LIMIT."
  (testscript--match-in-script testscript-command-re limit))

(defun testscript--match-negation (limit)
  "Font-lock matcher for ! and ? prefixes, up to LIMIT."
  (testscript--match-in-script
   "^\\(?:\\[!?[^]]+\\]\\s-*\\)*\\([!?]\\)\\s-" limit))

(defun testscript--match-condition (limit)
  "Font-lock matcher for condition guards, up to LIMIT."
  (testscript--match-in-script "^\\(\\[!?[^]]+\\]\\)" limit))

(defun testscript--match-env-var (limit)
  "Font-lock matcher for environment variables, up to LIMIT."
  (testscript--match-in-script "\\(\\$\\(?:{[^}]+}\\|[A-Za-z_][A-Za-z0-9_]*\\)\\)" limit))

(defun testscript--match-background (limit)
  "Font-lock matcher for background operator &, up to LIMIT."
  (testscript--match-in-script "\\(&\\)\\s-*$" limit))

(defvar testscript-font-lock-keywords
  `((,testscript-file-marker-re 0 'testscript-file-marker-face)
    (testscript--match-condition 1 font-lock-preprocessor-face)
    (testscript--match-negation 1 font-lock-negation-char-face)
    (testscript--match-command 1 font-lock-keyword-face)
    (testscript--match-env-var 1 font-lock-variable-name-face)
    (testscript--match-background 1 font-lock-type-face))
  "Font-lock keywords for `testscript-mode'.")

(defun testscript-imenu-create-index ()
  "Create an imenu index of txtar file markers."
  (let ((index nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^-- \\(.+?\\) --$" nil t)
        (push (cons (match-string-no-properties 1)
                    (match-beginning 0))
              index)))
    (nreverse index)))

(defun testscript-next-file-section ()
  "Move to the next txtar file marker line."
  (interactive)
  (let ((start (point)))
    (end-of-line)
    (if (re-search-forward testscript-file-marker-re nil t)
        (beginning-of-line)
      (goto-char start)
      (user-error "No more file sections"))))

(defun testscript-previous-file-section ()
  "Move to the previous txtar file marker line."
  (interactive)
  (let ((start (point)))
    (beginning-of-line)
    (if (re-search-backward testscript-file-marker-re nil t)
        (beginning-of-line)
      (goto-char start)
      (user-error "No previous file section"))))

(defvar testscript-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-n") #'testscript-next-file-section)
    (define-key map (kbd "C-c C-p") #'testscript-previous-file-section)
    map)
  "Keymap for `testscript-mode'.")

;;;###autoload
(define-derived-mode testscript-mode prog-mode "Testscript"
  "Major mode for editing testscript/txtar files.

Testscript files contain a script section with shell-like commands
followed by embedded file sections delimited by `-- FILENAME --' markers.

\\{testscript-mode-map}"
  :syntax-table testscript-mode-syntax-table
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "#+ *")
  (setq-local font-lock-defaults '(testscript-font-lock-keywords))
  (setq-local imenu-create-index-function #'testscript-imenu-create-index)
  (setq-local outline-regexp "^-- .+ --$")
  (setq-local outline-level (lambda () 1)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.txtar\\'" . testscript-mode))

(provide 'testscript-mode)

;;; testscript-mode.el ends here
